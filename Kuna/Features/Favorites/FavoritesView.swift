// Features/Favorites/FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    let api: VikunjaAPI
    @StateObject private var commentCountManager: CommentCountManager
    @State private var favoriteTasks: [VikunjaTask] = []
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedTask: VikunjaTask?
    @State private var showingTaskDetail = false

    init(api: VikunjaAPI) {
        self.api = api
        _commentCountManager = StateObject(wrappedValue: CommentCountManager(api: api))
    }

    var body: some View {
        Group {
            if isLoading && favoriteTasks.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2)
                    // Text("Loading favorites…").foregroundColor(.secondary)
                    Text(String(localized: "favorites.loading", comment: "Label shown when loading favorites"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favoriteTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle(String(localized: "common.favorites"))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("screen.favorites")
        .onAppear {
            loadFavorites()
            if AppSettings.shared.showCommentCounts {
                commentCountManager.loadCommentCounts(for: favoriteTasks.map { $0.id })
            }
        }
        .onChange(of: favoriteTasks.map { $0.id }) { _, newIds in
            if AppSettings.shared.showCommentCounts {
                commentCountManager.loadCommentCounts(for: newIds)
            }
        }
        .alert(String(localized: "common.error"),
               isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
               )
        ) {
            // Button("OK") { error = nil }
            Button(String(localized: "common.ok", comment: "OK button")) { error = nil }
            // Button("Retry") { loadFavorites() }
            Button(String(localized: "common.retry", comment: "Retry button")) { loadFavorites() }
        } message: {
            if let error { Text(error) }
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let task = selectedTask {
                TaskDetailView(task: task, api: api)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Text("No Favorite Tasks")
                Text(String(localized: "favorites.empty.title", comment: "Title shown when there are no favorites"))
                    .font(.title2).fontWeight(.semibold)
                // Text("Tasks you mark as favorites will appear here for quick access")
                Text(String(localized: "favorites.empty.subtitle", comment: "Subtitle shown when there are no favorites"))
                    .font(.body).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                    // Text("Tap the star icon on any task to add it to favorites")
                    Text(String(localized: "favorites.empty.tap_label", comment: "Label shown when there are no favorites"))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var taskListView: some View {
        List {
            ForEach(favoriteTasks) { task in
                FavoriteTaskRow(
                    task: task,
                    api: api,
                    projects: projects,
                    commentCountManager: commentCountManager
                ) { updatedTask in
                    if let index = favoriteTasks.firstIndex(where: { $0.id == updatedTask.id }) {
                        if updatedTask.isFavorite {
                            favoriteTasks[index] = updatedTask
                        } else {
                            favoriteTasks.remove(at: index)
                        }
                    }
                } onTap: {
                    selectedTask = task
                    showingTaskDetail = true
                }
                .onAppear {
                    let settings = AppSettings.shared
                    if settings.showCommentCounts {
                        commentCountManager.loadCommentCount(for: task.id)
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .refreshable { loadFavorites() }
    }

    private func loadFavorites() {
        isLoading = true
        error = nil

        Task {
            let t0 = Date()
            var outcome = "success"

            do {
                async let favoritesTask = api.getFavoriteTasks()
                async let projectsTask = api.fetchProjects()
                let (tasks, allProjects) = try await (favoritesTask, projectsTask)

                await MainActor.run {
                    projects = allProjects
                    favoriteTasks = tasks.sorted { a, b in
                        if a.done != b.done { return !a.done && b.done } // undone first
                        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                    }
                    isLoading = false
                }
            } catch is CancellationError {
                outcome = "cancelled"
                await MainActor.run { isLoading = false }
            } catch {
                outcome = "failure"
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }

            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.track(
                "Favorites.Fetch.View",
                parameters: [
                    "duration_ms": String(Int(ms)),
                    "outcome": outcome
                ],
                floatValue: ms
            )
        }
    }
}

struct FavoriteTaskRow: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let projects: [Project]
    let commentCountManager: CommentCountManager
    let onTaskUpdated: (VikunjaTask) -> Void
    let onTap: () -> Void

    @State private var isUpdatingFavorite = false
    @State private var isUpdatingDone = false
    @StateObject private var settings = AppSettings.shared

    private var project: Project? {
        guard let projectId = task.projectId else { return nil }
        return projects.first { $0.id == projectId }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleDone) {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.done ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingDone)
            .opacity(isUpdatingDone ? 0.6 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.body)
                        .foregroundColor(task.done ? .secondary : .primary)
                        .strikethrough(task.done)

                    if settings.showAttachmentIcons && task.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if settings.showCommentCounts {
                        let count = commentCountManager.getCommentCount(for: task.id) ?? 0
                        CommentBadge(commentCount: count)
                    }

                    Spacer()
                }

                if let project = project {
                    HStack(spacing: 4) {
                        Image(systemName: "folder").font(.caption2)
                        Text(project.title).font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(dueDate, style: .date)
                        }
                        .font(.caption2)
                        .foregroundColor(dueDate < Date() ? .red : .orange)
                    }
                    if let assignees = task.assignees, !assignees.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text(verbatim: "\(assignees.count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Button(action: toggleFavorite) {
                Image(systemName: task.isFavorite ? "star.fill" : "star")
                    .foregroundColor(task.isFavorite ? .yellow : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingFavorite)
            .opacity(isUpdatingFavorite ? 0.6 : 1.0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("favorite.row")
    }

    private func toggleFavorite() {
        isUpdatingFavorite = true
        Task {
            do {
                #if DEBUG
                Log.app.debug("FavoritesView: Toggling favorite for task id=\(task.id, privacy: .public) title=\(task.title, privacy: .public)")
                #endif
                let updated = try await api.toggleTaskFavorite(task: task)
                await MainActor.run {
                    #if DEBUG
                    Log.app.debug("FavoritesView: Task id=\(task.id, privacy: .public) favorite -> \(updated.isFavorite, privacy: .public)")
                    #endif
                    onTaskUpdated(updated)
                    isUpdatingFavorite = false
                }
            } catch {
                await MainActor.run {
                    #if DEBUG
                    Log.app.error("FavoritesView: Error toggling favorite for task id=\(task.id, privacy: .public): \(String(describing: error), privacy: .public)")
                    #endif
                    isUpdatingFavorite = false
                }
            }
    }
    }

    private func toggleDone() {
        isUpdatingDone = true
        Task {
            do {
                let updated = try await api.setTaskDone(task: task, done: !task.done)
                await MainActor.run {
                    onTaskUpdated(updated)
                    isUpdatingDone = false
                }
            } catch {
                await MainActor.run { isUpdatingDone = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView(api: VikunjaAPI(
            config: .init(baseURL: URL(string: "https://example.com")!), // swiftlint:disable:this force_unwrapping
            tokenProvider: { nil }
        ))
    }
}
