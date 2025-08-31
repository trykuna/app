import SwiftUI
import os

/// iPad split view: sidebar = tasks, detail = TaskDetailView.
struct TasksSplitContainerView: View {
    let project: Project
    let api: VikunjaAPI

    @StateObject private var vm: TaskListVM
    @State private var selection: VikunjaTask.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(project: Project, api: VikunjaAPI) {
        self.project = project
        self.api = api
        _vm = StateObject(wrappedValue: TaskListVM(api: api, projectId: project.id))
    }

    private var selectedTask: VikunjaTask? {
        guard let id = selection else { 
            #if DEBUG
            Log.app.debug("TasksSplitContainer: No selection")
            #endif
            return nil 
        }
        let task = vm.tasks.first(where: { $0.id == id })
        #if DEBUG
        Log.app.debug("TasksSplitContainer: Looking for task id \(id), found: \(task?.title ?? "nil")")
        #endif
        return task
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            if let task = selectedTask {
                TaskDetailView(task: task, api: api)
            } else {
                if #available(iOS 17, *) {
                    // ContentUnavailableView("Select a task", systemImage: "square.and.pencil")
                    ContentUnavailableView(String(localized: "tasks.select.title", comment: "Title for select a task"), systemImage: "square.and.pencil")
                } else {
                    // Text("Select a task")
                    Text(String(localized: "tasks.select.title", comment: "Title for select a task"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await vm.load()
            // Show both columns and pick a sensible default
            columnVisibility = .all
            selection = vm.tasks.first?.id
            #if DEBUG
            Log.app.debug("TasksSplitContainer: Loaded \(vm.tasks.count) tasks, selected: \(String(describing: selection))")
            #endif
        }
        .onChange(of: vm.tasks) { _, new in
            // Keep selection valid on refresh/pagination
            if let sel = selection, new.first(where: { $0.id == sel }) == nil {
                selection = new.first?.id
            } else if selection == nil {
                selection = new.first?.id
            }
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        List(selection: $selection) {
            Section(project.title) {
                ForEach(vm.tasks) { t in
                    Text(t.title)
                        .tag(t.id) // drives selection
                }

                if vm.hasMoreTasks {
                    HStack {
                        Spacer()
                        ProgressView().onAppear { Task { await vm.loadMoreTasks() } }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(String(localized: "tasks.title", comment: "Tasks"))
        .overlay {
            if vm.loading && vm.tasks.isEmpty {
                // ProgressView("Loading…")
                ProgressView(String(localized: "common.loading", comment: "Label shown when loading"))
            }
        }
        .refreshable { await vm.load(resetPagination: true) }
    }
}

// MARK: - TaskSidebarRow
struct TaskSidebarRow: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let onToggle: (VikunjaTask) -> Void
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox - prevent it from interfering with row selection
            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.done ? .green : .gray)
                .imageScale(.large)
                .onTapGesture {
                    onToggle(task)
                }

            // Color dot
            if settings.showTaskColors && (task.hasCustomColor || settings.showDefaultColorBalls) {
                Circle()
                    .fill(task.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            }

            // Priority icon
            if settings.showPriorityIndicators && task.priority != .unset {
                Image(systemName: task.priority.systemImage)
                    .foregroundColor(task.priority.color)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Title + extras
                HStack(spacing: 8) {
                    Text(task.title)
                        .strikethrough(task.done)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if settings.showAttachmentIcons && task.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                // Date info (condensed for sidebar)
                if let dueDate = task.dueDate, settings.showDueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock").font(.caption2)
                        Text(dueDate, style: .date).font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("task.row")
    }
}
