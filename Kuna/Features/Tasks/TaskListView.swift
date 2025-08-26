// Features/Tasks/TaskListView.swift
import SwiftUI
import UIKit
import EventKit
import ConfettiSwiftUI

// MARK: - View Extensions

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
}

struct FlowResult {
    var bounds = CGSize.zero
    var frames: [CGRect] = []

    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }

        bounds = CGSize(width: maxWidth, height: y + lineHeight)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func settingsCardStyle() -> some View {
        self
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "%02X%02X%02X", r, g, b)
    }
}

@MainActor
final class TaskListVM: ObservableObject {
    @Published var tasks: [VikunjaTask] = []
    @Published var loading = false
    @Published var loadingMore = false
    @Published var loadingOlder = false
    @Published var error: String?
    @Published var isAddingTask = false
    @Published var hasMoreTasks = true // whether there are more pages at the end
    @Published var totalTaskCount: Int? = nil // total tasks on server (from headers)

    private let api: VikunjaAPI
    private let projectId: Int

    // Pagination window tracking
    private var currentPage = 1 // next page to fetch at the end (kept for compatibility)
    private var firstLoadedPage = 1
    private var lastLoadedPage = 0
    private var totalPages: Int? = nil

    // Debounce for auto-load triggers
    private var lastTopTriggerTaskId: Int? = nil
    private var lastBottomTriggerTaskId: Int? = nil

    // Paging config and memory cap
    private let tasksPerPage = 50
    private let maxTasksInMemory = 200 // Reasonable limit for normal operation

    // Whether we can load older pages at the top (i.e. earlier pages were dropped)
    var canLoadPrevious: Bool { firstLoadedPage > 1 }

    init(api: VikunjaAPI, projectId: Int) {
        self.api = api; self.projectId = projectId
    }

    // Clean up memory when view model is deallocated
    deinit {
        Log.app.debug("TaskListVM: Deallocating for project \(self.projectId)")
        // Note: Cannot call async methods from deinit
        // The system will handle memory cleanup when the object is deallocated
    }

    // Clean up tasks when switching projects or leaving view
    func cleanup() {
        Log.app.debug("TaskListVM: Cleaning up tasks for project \(self.projectId)")
        tasks.removeAll()
        currentPage = 1
        firstLoadedPage = 1
        lastLoadedPage = 0
        totalPages = nil
        hasMoreTasks = true
        error = nil
    }

    func load(queryItems: [URLQueryItem] = [], resetPagination: Bool = true) async {
        if resetPagination {
            loading = true
            currentPage = 1
            firstLoadedPage = 1
            lastLoadedPage = 0
            totalPages = nil
            tasks = []
            hasMoreTasks = true
        } else {
            loadingMore = true
        }

        defer {
            loading = false
            loadingMore = false
        }

        let t0 = Date()
        let pageAtStart = currentPage

        do {
            let response = try await api.fetchTasks(
                projectId: projectId,
                page: currentPage,
                perPage: tasksPerPage,
                queryItems: queryItems
            )

            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.track("Task.Fetch.ListView", parameters: [
                "duration_ms": String(Int(ms)),
                "outcome": "success",
                "first_page": resetPagination ? "true" : "false",
                "page": String(pageAtStart)
            ],
            floatValue: ms)

            if resetPagination {
                tasks = response.tasks
                firstLoadedPage = response.currentPage
                lastLoadedPage = response.currentPage
                totalPages = response.totalPages
                // Prefer totalCount; if missing, derive from headers, else estimate
                if let count = response.totalCount {
                    totalTaskCount = count
                } else if let tp = response.totalPages {
                    totalTaskCount = tp * tasksPerPage
                } else {
                    totalTaskCount = (response.hasMore ? tasksPerPage + 1 : response.tasks.count)
                }
            } else {
                tasks.append(contentsOf: response.tasks)
                lastLoadedPage = response.currentPage
                totalPages = response.totalPages ?? totalPages
                totalTaskCount = response.totalCount ?? totalTaskCount
                // Limit the number of tasks in memory to prevent unbounded growth
                if tasks.count > maxTasksInMemory {
                    let excessCount = tasks.count - maxTasksInMemory
                    tasks.removeFirst(excessCount)
                    // Adjust firstLoadedPage if we dropped a full page (or more)
                    let pagesDropped = Int(ceil(Double(excessCount) / Double(tasksPerPage)))
                    self.firstLoadedPage = max(self.firstLoadedPage + pagesDropped, 1)
                    Log.app.debug("TaskListVM: Trimmed \(excessCount) old tasks, keeping \(self.tasks.count). Window pages=\(self.firstLoadedPage)-\(self.lastLoadedPage)")
                }
            }

            hasMoreTasks = response.hasMore
            currentPage = response.currentPage + 1
            // Reset auto-load sentinels after a successful page fetch
            lastTopTriggerTaskId = nil
            lastBottomTriggerTaskId = nil

            // Write widget cache after successful load (only for first page)
            if resetPagination {
                WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
                // Also write to shared file for watch
                SharedFileManager.shared.writeTasks(tasks, for: projectId)
            }
        }
        catch {
            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.track("Task.Fetch.ListView", parameters: [
                "duration_ms": String(Int(ms)),
                "outcome": "failure",
                "first_page": resetPagination ? "true" : "false",
                "page": String(pageAtStart)
            ],
            floatValue: ms)
            self.error = error.localizedDescription
        }
    }

    func loadMoreTasks(queryItems: [URLQueryItem] = []) async {
        guard hasMoreTasks && !loadingMore else { return }
        await load(queryItems: queryItems, resetPagination: false)
    }

    // Load the previous page (older index) when earlier pages were dropped
    func loadPreviousTasks(queryItems: [URLQueryItem] = []) async {
        guard !loadingOlder else { return }
        guard firstLoadedPage > 1 else { return }
        loadingOlder = true
        defer { loadingOlder = false }

        let targetPage = firstLoadedPage - 1
        let t0 = Date()
        do {
            let response = try await api.fetchTasks(
                projectId: projectId,
                page: targetPage,
                perPage: tasksPerPage,
                queryItems: queryItems
            )
            // Prepend tasks
            tasks.insert(contentsOf: response.tasks, at: 0)
            firstLoadedPage = targetPage

            // Enforce memory cap: if we exceed, drop from the end
            if tasks.count > maxTasksInMemory {
                let excess = tasks.count - maxTasksInMemory
                tasks.removeLast(excess)
                // If we dropped a full page from the end, adjust lastLoadedPage
                let pagesDropped = Int(ceil(Double(excess) / Double(tasksPerPage)))
                lastLoadedPage = max(lastLoadedPage - pagesDropped, firstLoadedPage)
            }

            // Update totals and hasMore flags
            totalPages = response.totalPages ?? totalPages
            totalTaskCount = response.totalCount ?? totalTaskCount
            if let total = totalPages {
                hasMoreTasks = lastLoadedPage < total
            }
            // Reset auto-load sentinels after a successful page fetch
            lastTopTriggerTaskId = nil
            lastBottomTriggerTaskId = nil

            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.track("Task.Fetch.ListView.Previous", parameters: [
                "duration_ms": String(Int(ms)),
                "outcome": "success",
                "page": String(targetPage)
            ], floatValue: ms)
        } catch {
            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.track("Task.Fetch.ListView.Previous", parameters: [
                "duration_ms": String(Int(ms)),
                "outcome": "failure",
                "page": String(targetPage)
            ], floatValue: ms)
            self.error = error.localizedDescription
        }
    }

    func toggle(_ task: VikunjaTask) async {
        do {
            let updated = try await api.setTaskDone(task: task, done: !task.done)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i] = updated
                // Update widget cache after task change
                WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            }
        } catch { self.error = error.localizedDescription }
    }

    func toggleFavorite(_ task: VikunjaTask) async {
        do {
            #if DEBUG
            Log.app.debug("TaskListView: Toggling favorite for task id=\(task.id, privacy: .public) title=\(task.title, privacy: .public) current=\(task.isFavorite, privacy: .public)")
            #endif
            let updated = try await api.toggleTaskFavorite(task: task)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                #if DEBUG
                Log.app.debug("TaskListView: Task id=\(task.id, privacy: .public) favorite -> \(updated.isFavorite, privacy: .public)")
                #endif
                tasks[i] = updated
                // Update widget cache after favorite change
                WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            }
        } catch {
            #if DEBUG
            Log.app.error("TaskListView: Error toggling favorite for task id=\(task.id, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
            self.error = error.localizedDescription
        }
    }

    func createTask(title: String, description: String?) async {
        do {
            let newTask = try await api.createTask(projectId: projectId, title: title, description: description)
            tasks.insert(newTask, at: 0)
            isAddingTask = false

            // Auto-sync to calendar if enabled
            let settings = AppSettings.shared
            let calendarSync = CalendarSyncService.shared
            if settings.calendarSyncEnabled && settings.autoSyncNewTasks {
                let hasRequiredDates = newTask.startDate != nil || newTask.dueDate != nil || newTask.endDate != nil
                if hasRequiredDates || !settings.syncTasksWithDatesOnly {
                    let _ = await calendarSync.syncTaskToCalendar(newTask)
                }
            }

            // Update widget cache after creating new task
            WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TaskListView: View {
    let project: Project
    let api: VikunjaAPI
    @StateObject private var vm: TaskListVM
    @StateObject private var settings = AppSettings.shared
    @StateObject private var calendarSync = CalendarSyncService.shared
    @ObservedObject private var commentCountManager: CommentCountManager
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""
    // Confetti trigger key
    @State private var confettiTrigger: Bool = false

    // Filter and Sort state
    @State private var currentFilter = TaskFilter()
    @State private var showingFilter = false
    @State private var currentSort: TaskSortOption
    @State private var showingSort = false

    init(project: Project, api: VikunjaAPI) {
        self.project = project
        self.api = api
        _vm = StateObject(wrappedValue: TaskListVM(api: api, projectId: project.id))
        _currentSort = State(initialValue: AppSettings.getDefaultSortOption())
        // Use shared instance to avoid creating multiple managers
        self.commentCountManager = CommentCountManager.getShared(api: api)
    }

    var filteredTasks: [VikunjaTask] {
        currentFilter.apply(to: vm.tasks)
    }

    var sortedAndGroupedTasks: [(String?, [VikunjaTask])] {
        let filtered = filteredTasks
        let sorted = sortTasks(filtered, by: currentSort)

        if currentSort.needsSectionHeaders {
            return groupTasksForSorting(sorted, by: currentSort)
        } else {
            return [(nil, sorted)]
        }
    }

    // Reduce SwiftUI churn: use an Equatable row view below
    private func sortTasks(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [VikunjaTask] {
        switch sortOption {
        case .serverOrder:
            return tasks // Return tasks in their original server order
        case .alphabetical:
            return tasks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .startDate:
            return tasks.sorted { task1, task2 in
                switch (task1.startDate, task2.startDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .endDate:
            return tasks.sorted { task1, task2 in
                switch (task1.endDate, task2.endDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                switch (task1.dueDate, task2.dueDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .priority:
            return tasks.sorted { $0.priority.rawValue > $1.priority.rawValue }
        }
    }

    private func groupTasksForSorting(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [(String?, [VikunjaTask])] {
        let calendar = Calendar.current
        let now = Date()

        switch sortOption {
        case .serverOrder:
            return [(nil, tasks)]
        case .alphabetical:
            return [(nil, tasks)]

        case .startDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let startDate = task.startDate else { return "No Start Date" }
                if calendar.isDateInToday(startDate) { return "Today" }
                if calendar.isDateInTomorrow(startDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(startDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: startDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.mediumDateFormatter.string(from: startDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .endDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let endDate = task.endDate else { return "No End Date" }
                if calendar.isDateInToday(endDate) { return "Today" }
                if calendar.isDateInTomorrow(endDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(endDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.mediumDateFormatter.string(from: endDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .dueDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let dueDate = task.dueDate else { return "No Due Date" }
                if calendar.isDateInToday(dueDate) { return "Today" }
                if calendar.isDateInTomorrow(dueDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(dueDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Overdue" }
                return DateFormatter.mediumDateFormatter.string(from: dueDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .priority:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                return task.priority == .unset ? "No Priority" : task.priority.displayName
            }
            let priorityOrder = [TaskPriority.doNow, .high, .medium, .low, .unset]
            return priorityOrder.compactMap { priority in
                let key = priority == .unset ? "No Priority" : priority.displayName
                if let tasks = grouped[key], !tasks.isEmpty {
                    return (key, tasks)
                }
                return nil
            }
        }
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }


            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private var mainContent: some View {
        Group {
            if vm.tasks.isEmpty && !vm.loading {
                emptyState
            } else {
                taskList
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Text("No Tasks Yet")
                Text(String(localized: "tasks.empty.title", comment: "Title shown when there are no tasks"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Text("This project doesn't have any tasks yet. Create your first task to get started!")
                Text(String(localized: "projects.empty.tasks", comment: "Title shown when there are no tasks"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                vm.isAddingTask = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    // Text("Create First Task")
                    Text(String(localized: "tasks.create.first", comment: "Title for create first task"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(25)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if vm.isAddingTask {
                addTaskOverlay
            }
        }
    }
    
    private var addTaskOverlay: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                // Text("Create New Task")
                Text(String(localized: "tasks.create.new", comment: "Title for create new task"))
                    .font(.headline)
                    .fontWeight(.semibold)
                TextField(String(localized: "tasks.placeholder.title", comment: "Task title"), text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "common.descriptionOptional"), text: $newTaskDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                HStack(spacing: 12) {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        vm.isAddingTask = false
                        newTaskTitle = ""
                        newTaskDescription = ""
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    // Button("Create Task") {
                    Button(String(localized: "tasks.create.button", comment: "Create task button")) {
                        Task {
                            await vm.createTask(
                                title: newTaskTitle,
                                description: newTaskDescription.isEmpty ? nil : newTaskDescription
                            )
                            newTaskTitle = ""
                            newTaskDescription = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .onTapGesture {
            vm.isAddingTask = false
            newTaskTitle = ""
            newTaskDescription = ""
        }
    }
    
    private var taskList: some View {
        List {
            if vm.isAddingTask {
                addNewTaskSection
            }
            // Top explicit trigger at the very top of the list
            if vm.canLoadPrevious || vm.loadingOlder {
                Section(footer: EmptyView()) {
                    if vm.loadingOlder {
                        HStack { Spacer(); ProgressView().padding(.vertical, 10); Spacer() }
                    } else if vm.canLoadPrevious {
                        HStack {
                            Spacer()
                            // Button("Load earlier") {
                            Button(String(localized: "tasks.list.loadEarlier", comment: "Load earlier button")) {
                                Task {
                                    let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                                    await vm.loadPreviousTasks(queryItems: query)
                                }
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                        }
                    }
                }
            }

            // Render sections and rows (no per-row onAppear to keep type-checking simple)
            ForEach(sortedAndGroupedTasks, id: \.0) { sectionTitle, tasks in
                if let sectionTitle = sectionTitle {
                    Section(header: Text(sectionTitle)) {
                        ForEach(tasks) { t in
                            taskRow(for: t)
                        }
                    }
                } else {
                    ForEach(tasks) { t in
                        taskRow(for: t)
                    }
                }
            }

            // Bottom explicit trigger for loading next pages
            Section(footer: EmptyView()) {
                if vm.loadingMore {
                    HStack { Spacer(); ProgressView().padding(.vertical, 12); Spacer() }
                } else if vm.hasMoreTasks {
                    HStack {
                        Spacer()
                        // Button("Load more") {
                        Button(String(localized: "tasks.list.loadMore", comment: "Load more button")) {
                            Task {
                                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                                await vm.loadMoreTasks(queryItems: query)
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.vertical, 12)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var addNewTaskSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField(String(localized: "tasks.placeholder.title", comment: "Task title"), text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "common.descriptionOptional"), text: $newTaskDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                HStack {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        vm.isAddingTask = false
                        newTaskTitle = ""
                        newTaskDescription = ""
                    }
                    .buttonStyle(.bordered)
                    // Button("Add Task") {
                    Button(String(localized: "tasks.create.add", comment: "Add task button")) {
                        Task {
                            await vm.createTask(
                                title: newTaskTitle,
                                description: newTaskDescription.isEmpty ? nil : newTaskDescription
                            )
                            newTaskTitle = ""
                            newTaskDescription = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            projectHeader
            Divider()
            mainContent
        }
        .accessibilityIdentifier("screen.tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .foregroundColor(currentFilter.hasActiveFilters ? .accentColor : .primary)
                    .accessibilityIdentifier("button.filter")
                    Button {
                        showingSort = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("button.sort")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.isAddingTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.isAddingTask)
                .accessibilityIdentifier("button.addTask")
            }
        }
        .sheet(isPresented: $showingFilter) {
            FilterView(
                filter: $currentFilter,
                isPresented: $showingFilter,
                availableLabels: []
            )
        }
        .actionSheet(isPresented: $showingSort) {
            ActionSheet(
                // title: Text("Sort Tasks"),
                title: Text(String(localized: "tasks.sort.title", comment: "Sort tasks action sheet title")),
                buttons: TaskSortOption.allCases.map { sortOption in
                    ActionSheet.Button.default(
                        Text(sortOption.rawValue),
                        action: { currentSort = sortOption }
                    )
                } + [ActionSheet.Button.cancel()]
            )
        }
        .onAppear {
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query, resetPagination: true)
                if settings.showCommentCounts {
                    commentCountManager.loadCommentCounts(for: vm.tasks.map { $0.id })
                }
            }
        }
        .onChange(of: currentFilter) { _, _ in
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query, resetPagination: true)
                if settings.showCommentCounts {
                    commentCountManager.clearCache()
                    commentCountManager.loadCommentCounts(for: vm.tasks.map { $0.id })
                }
            }
        }
        .onChange(of: settings.defaultSortOption) { _, newSortOption in
            currentSort = newSortOption
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Log.app.warning("TaskListView: Received memory warning - reducing task list size")
            if vm.tasks.count > 5 {
                let keepCount = 5
                vm.tasks = Array(vm.tasks.prefix(keepCount))
                Log.app.debug("TaskListView: Trimmed to \(keepCount) tasks due to memory warning")
            }
            commentCountManager.clearCache()
        }
        .overlay(ConfettiOverlay(trigger: $confettiTrigger).allowsHitTesting(false))
    }

    // Lightweight confetti host to keep type-checking simple
    private struct ConfettiOverlay: View {
        @Binding var trigger: Bool
        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .confettiCannon(trigger: $trigger,
                                    num: 30,
                                    confettis: [.text("🎉"), .text("🎊"), .text("⭐️")],
                                    confettiSize: 12)
            }
        }
    }

    @ViewBuilder
    private func taskRow(for t: VikunjaTask) -> some View {
        TaskRowView(
            props: TaskRowProps(
                t: t,
                showTaskColors: settings.showTaskColors,
                showDefaultColorBalls: settings.showDefaultColorBalls,
                showPriorityIndicators: settings.showPriorityIndicators,
                showAttachmentIcons: settings.showAttachmentIcons,
                showCommentCounts: settings.showCommentCounts,
                showStartDate: settings.showStartDate,
                showDueDate: settings.showDueDate,
                showEndDate: settings.showEndDate,
                commentCount: commentCountManager.getCommentCount(for: t.id)
            ),
            api: api,
            onToggle: { task in
                let willMarkDone = !task.done
                Task {
                    await vm.toggle(task)
                    if willMarkDone && settings.celebrateCompletionConfetti {
                        if !UIAccessibility.isReduceMotionEnabled { confettiTrigger.toggle() }
                    }
                }
            }
        )

        .swipeActions(edge: .leading) {
            Button {
                let willMarkDone = !t.done
                Task {
                    await vm.toggle(t)
                    if willMarkDone && settings.celebrateCompletionConfetti {
                        if !UIAccessibility.isReduceMotionEnabled { confettiTrigger.toggle() }
                    }
                }
            } label: {
                Image(systemName: t.done ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(t.done ? .orange : .green)

            Button {
                Task { await vm.toggleFavorite(t) }
            } label: {
                Image(systemName: t.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button {
                Task {
                    do {
                        try await api.deleteTask(taskId: t.id)
                        await vm.load(queryItems: currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : [], resetPagination: true) // Refresh the task list
                    } catch {
                        vm.error = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
        // Remove individual onAppear to prevent overwhelming the comment API
        // Comment counts are now loaded in batches in the main view's onAppear
    }

    private func isReminderSoon(_ reminderDate: Date) -> Bool {
        let now = Date()
        let timeDifference = reminderDate.timeIntervalSince(now)
        return timeDifference <= 3600 && timeDifference > 0 // Within 1 hour from now
    }

    private func isTaskSyncedToCalendar(_ task: VikunjaTask) -> Bool {
        let hasAccess: Bool
        if #available(iOS 17.0, *) {
            hasAccess = CalendarSyncService.shared.authorizationStatus == .fullAccess
        } else {
            hasAccess = CalendarSyncService.shared.authorizationStatus == .authorized
        }

        guard hasAccess,
              let calendar = CalendarSyncService.shared.selectedCalendar else {
            return false
        }

        let predicate = CalendarSyncService.shared.eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
            end: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days from now
            calendars: [calendar]
        )

        let events = CalendarSyncService.shared.eventStore.events(matching: predicate)
        return events.contains { event in
            event.url?.absoluteString == "kuna://task/\(task.id)"
        }
    }
}
