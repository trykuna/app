// Features/Favorites/FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    let api: VikunjaAPI
    @State private var favoriteTasks: [VikunjaTask] = []
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedTask: VikunjaTask?
    @State private var showingTaskDetail = false
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2)
                    Text("Loading favorites…").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favoriteTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadFavorites() }
        .alert("Error",
               isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
               )
        ) {
            Button("OK") { error = nil }
            Button("Retry") { loadFavorites() }
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
                Text("No Favorite Tasks")
                    .font(.title2).fontWeight(.semibold)
                Text("Tasks you mark as favorites will appear here for quick access")
                    .font(.body).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                    Text("Tap the star icon on any task to add it to favorites")
                        .font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").foregroundColor(.red)
                    Text("Favorite tasks sync across all your devices")
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
                    projects: projects
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
            do {
                async let favoritesTask = api.getFavoriteTasks()
                async let projectsTask = api.fetchProjects()
                let (tasks, allProjects) = try await (favoritesTask, projectsTask)
                await MainActor.run {
                    projects = allProjects
                    favoriteTasks = tasks.sorted { a, b in
                        if a.done != b.done { return !a.done && b.done }
                        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct FavoriteTaskRow: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let projects: [Project]
    let onTaskUpdated: (VikunjaTask) -> Void
    let onTap: () -> Void

    @State private var isUpdatingFavorite = false

    private var project: Project? {
        guard let projectId = task.projectId else { return nil }
        return projects.first { $0.id == projectId }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Button(action: {
                    // TODO: Implement task completion toggle
                }) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.done ? .green : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .foregroundColor(task.done ? .secondary : .primary)
                        .strikethrough(task.done)

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
                                Text("\(assignees.count)")
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
        }
        .buttonStyle(.plain)
    }
    
    private func toggleFavorite() {
        isUpdatingFavorite = true
        Task {
            do {
                #if DEBUG
                print("FavoritesView: Toggling favorite for task \(task.id): \(task.title)")
                #endif
                let updated = try await api.toggleTaskFavorite(task: task)
                await MainActor.run {
                    #if DEBUG
                    print("FavoritesView: Task \(task.id) favorite status changed to: \(updated.isFavorite)")
                    #endif
                    onTaskUpdated(updated)
                    isUpdatingFavorite = false
                }
            } catch {
                await MainActor.run {
                    #if DEBUG
                    print("FavoritesView: Error toggling favorite for task \(task.id): \(error)")
                    #endif
                    isUpdatingFavorite = false
                }
            }
        }
    }
}

#Preview {
    // Wrap in a NavigationStack only for the preview
    NavigationStack {
        FavoritesView(api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil }))
    }
}
