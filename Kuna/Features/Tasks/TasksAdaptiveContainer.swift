import SwiftUI
import os

/// Picks the right container for the current size class.
/// - iPhone: TaskListView (pushes detail)
/// - iPad:   TasksIPadSplitView (sidebar + detail)
struct TasksAdaptiveContainer: View {
    @Environment(\.horizontalSizeClass) private var hSize
    let project: Project
    let api: VikunjaAPI

    var body: some View {
        if hSize == .compact {
            // iPhone: Traditional navigation
            TaskListView(project: project, api: api)
        } else {
            // iPad: Custom split view using HStack
            TasksIPadSplitView(project: project, api: api)
        }
    }
}

// MARK: - iPad Split View
struct TasksIPadSplitView: View {
    let project: Project
    let api: VikunjaAPI
    
    @StateObject private var vm: TaskListVM
    @StateObject private var settings = AppSettings.shared
    @StateObject private var calendarSync = CalendarSyncService.shared
    @ObservedObject private var commentCountManager: CommentCountManager
    
    @State private var selectedTask: VikunjaTask?
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""
    
    // Filter and Sort state
    @State private var currentFilter = TaskFilter()
    @State private var showingFilter = false
    @State private var currentSort: TaskSortOption
    @State private var showingSort = false
    @State private var showingDisplayOptions = false
    
    init(project: Project, api: VikunjaAPI) {
        self.project = project
        self.api = api
        _vm = StateObject(wrappedValue: TaskListVM(api: api, projectId: project.id))
        _currentSort = State(initialValue: AppSettings.getDefaultSortOption())
        self.commentCountManager = CommentCountManager.getShared(api: api)
    }
    
    var filteredTasks: [VikunjaTask] {
        currentFilter.apply(to: vm.tasks)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar - Task List
            taskListSidebar
                .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            
            Divider()
            
            // Right detail - Task Detail
            taskDetailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("screen.tasks")
        .onAppear {
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query, resetPagination: true)
                
                if settings.showCommentCounts {
                    commentCountManager.loadCommentCounts(for: vm.tasks.map { $0.id })
                }
            }
        }
        .onChange(of: vm.tasks) { _, newTasks in
            #if DEBUG
            Log.app.debug("TasksIPadSplitView: Tasks changed, count: \(newTasks.count)")
            Log.app.debug("TasksIPadSplitView: Current selectedTask: \(selectedTask?.title ?? "nil")")
            #endif
            
            // Auto-select first task if none selected and we have tasks
            if selectedTask == nil && !newTasks.isEmpty {
                selectedTask = newTasks.first
                #if DEBUG
                Log.app.debug("TasksIPadSplitView: Auto-selected first task: \(selectedTask?.title ?? "nil")")
                #endif
            }
            // If current selection exists, update it with the latest data
            else if let current = selectedTask, let updatedTask = newTasks.first(where: { $0.id == current.id }) {
                selectedTask = updatedTask
                #if DEBUG
                Log.app.debug("TasksIPadSplitView: Updated selectedTask with fresh data: \(updatedTask.title)")
                #endif
            }
            // If current selection is no longer valid, select first available task
            else if let current = selectedTask, !newTasks.contains(where: { $0.id == current.id }) {
                selectedTask = newTasks.first
                #if DEBUG
                Log.app.debug("TasksIPadSplitView: Previous selection invalid, selected: \(selectedTask?.title ?? "nil")")
                #endif
            }
        }
        .onChange(of: currentFilter) { _, _ in
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query, resetPagination: true)
                // Reset selection after filter change
                selectedTask = vm.tasks.first
                if settings.showCommentCounts {
                    commentCountManager.clearCache()
                    commentCountManager.loadCommentCounts(for: vm.tasks.map { $0.id })
                }
            }
        }
        .onChange(of: settings.defaultSortOption) { _, newSortOption in
            currentSort = newSortOption
        }
        .sheet(isPresented: $showingFilter) {
            FilterView(
                filter: $currentFilter,
                isPresented: $showingFilter,
                availableLabels: []
            )
        }
        .sheet(isPresented: $showingDisplayOptions) {
            TaskDisplayOptionsView()
        }
        .actionSheet(isPresented: $showingSort) {
            ActionSheet(
                // title: Text("Sort Tasks"),
                title: Text(String(localized: "tasks.sort.title", comment: "Title for sort tasks")),
                buttons: TaskSortOption.allCases.map { sortOption in
                    ActionSheet.Button.default(
                        Text(sortOption.rawValue),
                        action: { currentSort = sortOption }
                    )
                } + [ActionSheet.Button.cancel()]
            )
        }
    }
    
    // MARK: - Task List Sidebar
    private var taskListSidebar: some View {
        VStack(spacing: 0) {
            // Header with project title and toolbar
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
                    
                    Spacer()
                    
                    // Toolbar buttons
                    HStack(spacing: 8) {
                        Button {
                            showingDisplayOptions = true
                        } label: {
                            Image(systemName: "eye")
                        }
                        .accessibilityIdentifier("button.displayOptions")
                        
                        Button {
                            showingFilter = true
                        } label: {
                            Image(systemName: currentFilter.hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle")
                        }
                        .foregroundColor(currentFilter.hasActiveFilters ? .accentColor : .primary)
                        .accessibilityIdentifier("button.filter")
                        
                        Button {
                            showingSort = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityIdentifier("button.sort")
                        
                        Button {
                            vm.isAddingTask = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(vm.isAddingTask)
                        .accessibilityIdentifier("button.addTask")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color(.systemBackground))
            
            Divider()
            
            // Task List
            if vm.tasks.isEmpty && !vm.loading {
                emptyState
            } else {
                taskList
            }
        }
    }
    
    // MARK: - Task Detail View
    private var taskDetailView: some View {
        NavigationStack {
            if let task = selectedTask {
                #if DEBUG
                let _ = Log.app.debug("TasksIPadSplitView: Rendering TaskDetailView for task: \(task.title)")
                #endif
                // Extract just the content from TaskDetailView without the NavigationView wrapper
                TaskDetailViewInner(
                    task: Binding(
                        get: { selectedTask! },
                        set: { newTask in 
                            selectedTask = newTask
                            // Update the task in the VM when it's edited
                            if let index = vm.tasks.firstIndex(where: { $0.id == newTask.id }) {
                                vm.tasks[index] = newTask
                            }
                        }
                    ),
                    api: api
                ) { updatedTask in
                    // Update the task in the VM when it's edited
                    if let index = vm.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                        vm.tasks[index] = updatedTask
                        selectedTask = updatedTask // Keep selectedTask in sync
                    }
                }
                .navigationTitle(task.title)
                .navigationBarTitleDisplayMode(.large)
            } else {
                #if DEBUG
                let _ = Log.app.debug("TasksIPadSplitView: No task selected, showing empty state")
                #endif
                VStack(spacing: 20) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    // Text("Select a task to view its details")
                    Text(String(localized: "tasks.select.description", comment: "Title shown when no task is selected"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Text("No Tasks Yet")
                Text(String(localized: "tasks.empty.title", comment: "Title shown when there are no tasks"))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Text("Create your first task to get started!")
                Text(String(localized: "tasks.empty.action", comment: "Title shown when there are no tasks"))
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
    
    // MARK: - Task List
    private var taskList: some View {
        List {
            if vm.isAddingTask {
                addNewTaskSection
            }
            
            ForEach(filteredTasks) { task in
                taskRow(for: task)
                    .listRowBackground(
                        selectedTask?.id == task.id ? 
                        Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .onTapGesture {
                        #if DEBUG
                        Log.app.debug("TasksIPadSplitView: Tapped task: \(task.title)")
                        #endif
                        selectedTask = task
                        #if DEBUG
                        Log.app.debug("TasksIPadSplitView: Selected task set to: \(selectedTask?.title ?? "nil")")
                        #endif
                    }
                    .onAppear {
                        // Auto-load more tasks when we reach near the end
                        if task == filteredTasks.last, vm.hasMoreTasks && !vm.loadingMore {
                            Task {
                                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                                await vm.loadMoreTasks(queryItems: query)
                            }
                        }
                    }
            }
            
            // Bottom explicit trigger for loading next pages
            Section(footer: EmptyView()) {
                if vm.loadingMore {
                    HStack { 
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 12)
                        Spacer()
                    }
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
        .listStyle(.plain)
        .refreshable {
            let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
            await vm.load(queryItems: query, resetPagination: true)
        }
        .overlay {
            if vm.loading && vm.tasks.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    // Text("Loading tasks...")
                    Text(String(localized: "tasks.loading", comment: "Label shown when loading tasks"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }
    
    // MARK: - Task Row
    @ViewBuilder
    private func taskRow(for task: VikunjaTask) -> some View {
        // Use the same TaskRowContent as iPhone version for consistency
        TaskRowContent(
            props: TaskRowProps(
                t: task,
                showTaskColors: settings.showTaskColors,
                showDefaultColorBalls: settings.showDefaultColorBalls,
                showPriorityIndicators: settings.showPriorityIndicators,
                showAttachmentIcons: settings.showAttachmentIcons,
                showCommentCounts: settings.showCommentCounts,
                showStartDate: settings.showStartDate,
                showDueDate: settings.showDueDate,
                showEndDate: settings.showEndDate,
                commentCount: commentCountManager.getCommentCount(for: task.id)
            ),
            api: api,
            onToggle: { task in
                Task { await vm.toggle(task) }
            }
        )
        .accessibilityIdentifier("task.row")
    }
    
    // MARK: - Add Task Overlay and Section
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
                    Button(String(localized: "tasks.add.title", comment: "Add task button")) {
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
}

// MARK: - TaskDetailContentView
/// A version of TaskDetailView without the NavigationView wrapper
struct TaskDetailContentView: View {
    @State private var task: VikunjaTask
    let api: VikunjaAPI
    let onTaskUpdated: (VikunjaTask) -> Void
    
    init(task: VikunjaTask, api: VikunjaAPI, onTaskUpdated: @escaping (VikunjaTask) -> Void = { _ in }) {
        self._task = State(initialValue: task)
        self.api = api
        self.onTaskUpdated = onTaskUpdated
    }
    
    var body: some View {
        // Create TaskDetailView and extract just the content, not the NavigationView
        TaskDetailViewInner(task: $task, api: api, onTaskUpdated: onTaskUpdated)
            .navigationTitle(task.title)
            .navigationBarTitleDisplayMode(.large)
    }
}

/// Internal view that replicates TaskDetailView content without NavigationView
struct TaskDetailViewInner: View {
    @Binding var task: VikunjaTask
    let api: VikunjaAPI
    let onTaskUpdated: (VikunjaTask) -> Void
    
    @State private var isEditing = false
    @State private var hasChanges = false
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var isUpdatingFavorite = false
    
    // Editing state
    @State private var editedTitle = ""
    @State private var editedDescription = ""
    @State private var editedPriority = TaskPriority.unset
    @State private var editedDueDate: Date?
    @State private var editedStartDate: Date?
    @State private var editedEndDate: Date?
    @State private var editedPercentDone: Double = 0
    @State private var editedColor = Color.clear
    @State private var availableLabels: [Label] = []
    @State private var selectedLabelIds: Set<Int> = []
    
    // Sheets/pickers
    @State private var showingLabelPicker = false
    @State private var showingColorPicker = false
    @State private var showingRemindersEditor = false
    @State private var showingRepeatEditor = false
    @State private var showingUserSearch = false
    @State private var showingComments = false
    @State private var showingRelatedTasks = false
    
    // Has time toggles for dates
    @State private var startHasTime = false
    @State private var dueHasTime = false
    @State private var endHasTime = false
    
    // Task Loading States
    @State private var isLoadingLabels = false
    @State private var newReminderDate = Date().addingTimeInterval(3600)
    
    // Repeat settings editing state
    @State private var editedRepeatAfter: Int = 0
    @State private var editedRepeatMode: RepeatMode = .afterAmount
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentScrollView
            bottomToolbar
        }
        .onAppear {
            initializeEditingState()
            Task { await loadAvailableLabels() }
        }
        .onChange(of: task) { _, newTask in
            initializeEditingState()
        }
        .alert(String(localized: "common.error"), isPresented: .constant(updateError != nil)) {
            // Button("OK") {
            Button(String(localized: "common.ok", comment: "OK button")) { updateError = nil }
        } message: {
            if let error = updateError { Text(error) }
        }
        .sheet(isPresented: $showingLabelPicker) {
            labelPickerSheet
        }
        .sheet(isPresented: $showingColorPicker) {
            colorPickerSheet
        }
        .sheet(isPresented: $showingRemindersEditor) {
            remindersEditorSheet
        }
        .sheet(isPresented: $showingRepeatEditor) {
            repeatEditorSheet
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView(api: api) { user in
                Task {
                    await assignUser(user)
                }
            }
        }
        .sheet(isPresented: $showingComments, onDismiss: {
            // Reset navigation state after comments sheet dismissal
            // This helps ensure sidebar accessibility is restored
            DispatchQueue.main.async {
                #if DEBUG
                Log.app.debug("Comments sheet dismissed - navigation state should be reset")
                #endif
            }
        }) {
            // Use NavigationStack instead of CommentsView's NavigationView to avoid conflicts
            NavigationStack {
                CommentsContentView(task: task, api: api, commentCountManager: CommentCountManager(api: api))
            }
        }
        .sheet(isPresented: $showingRelatedTasks, onDismiss: {
            // Reset navigation state after related tasks sheet dismissal
            DispatchQueue.main.async {
                #if DEBUG
                Log.app.debug("Related tasks sheet dismissed - navigation state should be reset")
                #endif
            }
        }) {
            RelatedTasksView(task: Binding.constant(task), api: api)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            // Text("Task Details")
            Text(String(localized: "tasks.details.title", comment: "Title for task details"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Favorite button
            Button(action: toggleFavorite) {
                Image(systemName: task.isFavorite ? "star.fill" : "star")
                    .foregroundColor(task.isFavorite ? .yellow : .gray)
            }
            .disabled(isUpdatingFavorite)
            
            // Edit/Done button
            Button(isEditing 
                    ? String(localized: "common.done", comment: "Done button")
                    : String(localized: "common.edit", comment: "Edit button")) {
                if isEditing {
                    if hasChanges {
                        Task { await saveChanges() }
                    } else {
                        isEditing = false
                    }
                } else {
                    startEditing()
                }
            }
            .fontWeight(.medium)
            .disabled(isUpdating)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var contentScrollView: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // TASK INFO Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Text("TASK INFO")
                        Text(String(localized: "tasks.info.title", comment: "Title for task info"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Title Row
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                if isEditing {
                                    TextField(String(localized: "tasks.placeholder.title",
                                                    comment: "Task Title"), text: $editedTitle)
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .onChange(of: editedTitle) { _, _ in
                                            hasChanges = true
                                        }
                                } else {
                                    Text(task.title)
                                        .font(.body)
                                    Spacer()
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Description Row
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                if isEditing {
                                    // TextField("Add description...", text: $editedDescription, axis: .vertical)
                                    TextField(
                                        String(localized: "tasks.details.description.placeholder", 
                                               comment: "Placeholder for adding description"),
                                        text: $editedDescription,
                                        axis: .vertical
                                    )
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .lineLimit(3...6)
                                        .onChange(of: editedDescription) { _, _ in
                                            hasChanges = true
                                        }
                                } else {
                                    if let desc = task.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.body)
                                    } else {
                                        // Text("No description")
                                        Text(String(localized: "tasks.details.description.none",
                                                    comment: "Title for no description"))
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // SCHEDULING Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Text("SCHEDULING")
                        Text(String(localized: "tasks.details.scheduling.title", comment: "Title for scheduling"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Start Date Row
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("Start Date")
                                    Text(String(localized: "tasks.details.dates.startDate.title",
                                                comment: "Title for start date"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if isEditing {
                                        HStack {
                                            if editedStartDate != nil {
                                                // DatePicker("Start Date", selection: Binding(
                                                DatePicker(String(localized: "tasks.startDate",
                                                                comment: "Start date picker"), 
                                                        selection: Binding(
                                                            get: { editedStartDate ?? Date() },
                                                            set: { editedStartDate = $0; hasChanges = true }
                                                ), displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                
                                                // Button("Remove") {
                                                Button(String(localized: "common.remove", comment: "Remove button")) {
                                                    editedStartDate = nil
                                                    hasChanges = true
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            } else {
                                                // Button("Add Start Date") {
                                                Button(String(localized: "tasks.details.dates.startDate.add",
                                                                comment: "Add start date")) {
                                                    editedStartDate = Date()
                                                    hasChanges = true
                                                }
                                                .font(.body)
                                            }
                                        }
                                    } else {
                                        if let startDate = task.startDate {
                                            Text(startDate, style: .date)
                                                .font(.callout)
                                            Text(startDate, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            // Text("No start date")
                                            Text(String(localized: "tasks.details.dates.startDate.none",
                                                            comment: "Title for no start date"))
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Due Date Row
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("Due Date")
                                    Text(String(localized: "tasks.details.dates.dueDate.title", comment: "Title for due date"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if isEditing {
                                        HStack {
                                            if editedDueDate != nil {
                                                DatePicker(String(localized: "tasks.detail.dueDate"), selection: Binding(
                                                    get: { editedDueDate ?? Date() },
                                                    set: { editedDueDate = $0; hasChanges = true }
                                                ), displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                
                                                // Button("Remove") {
                                                Button(String(localized: "common.remove", comment: "Remove button")) {
                                                    editedDueDate = nil
                                                    hasChanges = true
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            } else {
                                                // Button("Add Due Date") {
                                                Button(String(localized: "tasks.details.dates.dueDate.add",
                                                                comment: "Add due date")) {
                                                    editedDueDate = Date()
                                                    hasChanges = true
                                                }
                                                .font(.body)
                                            }
                                        }
                                    } else {
                                        if let dueDate = task.dueDate {
                                            Text(dueDate, style: .date)
                                                .font(.callout)
                                            Text(dueDate, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            // Text("No due date")
                                            Text(String(localized: "tasks.details.dates.dueDate.none",
                                                            comment: "Title for no due date"))
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // End Date Row
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("End Date")
                                    Text(String(localized: "tasks.details.dates.endDate.title", comment: "Title for end date"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if isEditing {
                                        HStack {
                                            if editedEndDate != nil {
                                                DatePicker(String(localized: "tasks.detail.endDate"), selection: Binding(
                                                    get: { editedEndDate ?? Date() },
                                                    set: { editedEndDate = $0; hasChanges = true }
                                                ), displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                
                                                // Button("Remove") {
                                                Button(String(localized: "common.remove", comment: "Remove button")) {
                                                    editedEndDate = nil
                                                    hasChanges = true
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            } else {
                                                // Button("Add End Date") {
                                                Button(String(localized: "tasks.details.dates.endDate.add",
                                                                comment: "Add end date")) {
                                                    editedEndDate = Date()
                                                    hasChanges = true
                                                }
                                                .font(.body)
                                            }
                                        }
                                    } else {
                                        if let endDate = task.endDate {
                                            Text(endDate, style: .date)
                                                .font(.callout)
                                            Text(endDate, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            // Text("No end date")
                                            Text(String(localized: "tasks.details.dates.endDate.none",
                                                            comment: "Title for no end date"))
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            
                            Divider().padding(.leading, 16)
                            
                            // Reminders Row
                            HStack(spacing: 12) {
                                Image(systemName: "bell")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("Reminders")
                                    Text(String(localized: "tasks.details.reminders.title", comment: "Title for reminders"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if let reminders = task.reminders, !reminders.isEmpty {
                                        ForEach(reminders, id: \.id) { reminder in
                                            Text(reminder.reminder, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        // Text("No reminders")
                                        Text(String(localized: "tasks.details.reminders.none", comment: "Title for no reminders"))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if isEditing {
                                    // Button("Edit") {
                                    Button(String(localized: "common.edit", comment: "Edit button")) {
                                        showingRemindersEditor = true
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 16)
                            
                            // Repeat Row
                            HStack(spacing: 12) {
                                Image(systemName: "repeat")
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("Repeat")
                                    Text(String(localized: "tasks.details.repeat.title", comment: "Title for repeat"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
                                        Text("Every \(repeatAfter) \(task.repeatMode.displayName)")
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    } else {
                                        // Text("Never")
                                        Text(String(localized: "common.never", comment: "Title for never"))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if isEditing {
                                    // Button("Edit") {
                                    Button(String(localized: "common.edit", comment: "Edit button")) {
                                        showingRepeatEditor = true
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // ORGANIZATION Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Text("ORGANIZATION")
                        Text(String(localized: "common.organization", comment: "Title for organization"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Priority Row
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                if isEditing {
                                    // Picker("Priority", selection: $editedPriority) {
                                    Picker(
                                        String(localized: "tasks.detail.priority.title", comment: "Priority picker"),
                                        selection: $editedPriority
                                    ) {
                                        Text(String(localized: "common.none",
                                                    comment: "None priority")).tag(TaskPriority.unset)
                                        Text(String(localized: "common.low",
                                                    comment: "Low priority")).tag(TaskPriority.low)
                                        Text(String(localized: "common.medium",
                                                    comment: "Medium priority")).tag(TaskPriority.medium)
                                        Text(String(localized: "common.high",
                                                    comment: "High priority")).tag(TaskPriority.high)
                                        Text(String(localized: "common.urgent",
                                                    comment: "Urgent priority")).tag(TaskPriority.urgent)
                                        Text(String(localized: "common.doNow",
                                                    comment: "Do now priority")).tag(TaskPriority.doNow)
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: editedPriority) { _, _ in
                                        hasChanges = true
                                    }
                                    Spacer()
                                } else {
                                    if task.priority != .unset {
                                        HStack {
                                            Image(systemName: task.priority.systemImage)
                                                .foregroundColor(task.priority.color)
                                            Text(task.priority.displayName)
                                        }
                                    } else {
                                        // Text("No priority")
                                        Text(String(localized: "tasks.details.priority.none", comment: "Title for no priority"))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Progress Row
                            HStack(spacing: 12) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        // Text("Progress")
                                        Text(String(localized: "tasks.details.progress.title", comment: "Title for progress"))
                                            .font(.body)
                                        Spacer()
                                        Text("\(Int(isEditing ? editedPercentDone : task.percentDone))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if isEditing {
                                        Slider(value: $editedPercentDone, in: 0...100, step: 5)
                                            .onChange(of: editedPercentDone) { _, _ in
                                                hasChanges = true
                                            }
                                    } else {
                                        ProgressView(value: task.percentDone, total: 100)
                                            .tint(.blue)
                                    }
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Labels Row
                            HStack(spacing: 12) {
                                Image(systemName: "tag")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        // Text("Labels")
                                        Text(String(localized: "labels.title", comment: "Title for labels"))
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            // Button("Edit") {
                                    Button(String(localized: "common.edit", comment: "Edit button")) {
                                                showingLabelPicker = true
                                            }
                                            .font(.caption)
                                        }
                                    }
                                    
                                    if let labels = task.labels, !labels.isEmpty {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                            ForEach(labels) { label in
                                                Text(label.title)
                                                    .font(.caption)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(label.color.opacity(0.2))
                                                    .foregroundColor(label.color)
                                                    .cornerRadius(6)
                                            }
                                        }
                                    } else {
                                        // Text("No labels")
                                        Text(String(localized: "tasks.details.labels.none", comment: "Title for no labels"))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Color Row
                            HStack(spacing: 12) {
                                Image(systemName: "paintpalette")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Text("Color")
                                    Text(String(localized: "common.colour", comment: "Title for color"))
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Circle()
                                            .fill(isEditing ? editedColor : task.color)
                                            .frame(width: 20, height: 20)
                                            .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                                        
                                        Text(isEditing 
                                                ? String(localized: "common.custom")
                                                : String(localized: "settings.display.colours.title"))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            // Button("Edit") {
                                    Button(String(localized: "common.edit", comment: "Edit button")) {
                                                showingColorPicker = true
                                            }
                                            .font(.caption)
                                        }
                                    }
                                }
                            }
                            .padding()
                            
                            Divider().padding(.leading, 48)
                            
                            // Assignees Row
                            HStack(spacing: 12) {
                                Image(systemName: "person.2")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        // Text("Assignees")
                                        Text(String(localized: "tasks.details.assignees.title", comment: "Title for assignees"))
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            Button(String(localized: "common.add", comment: "Add")) {
                                                showingUserSearch = true
                                            }
                                            .font(.caption)
                                        }
                                    }
                                    
                                    if let assignees = task.assignees, !assignees.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(assignees) { assignee in
                                                HStack(spacing: 8) {
                                                    Image(systemName: "person.circle.fill")
                                                        .foregroundColor(.blue)
                                                        .font(.caption)
                                                    
                                                    Text(assignee.displayName)
                                                        .font(.callout)
                                                    
                                                    if isEditing {
                                                        // Button("Remove") {
                                                Button(String(localized: "common.remove", comment: "Remove button")) {
                                                            Task {
                                                                await removeAssignee(userId: assignee.id)
                                                            }
                                                        }
                                                        .font(.caption2)
                                                        .foregroundColor(.red)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                            }
                                        }
                                    } else {
                                        // Text("No assignees")
                                        Text(String(localized: "tasks.details.assignees.none", comment: "Title for no assignees"))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Action Buttons Section
                    VStack(spacing: 12) {
                        // Related Tasks Button
                        Button {
                            showingRelatedTasks = true
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                // Text("Related Tasks")
                                Text(String(localized: "tasks.details.relatedTasks.title", comment: "Title for related tasks"))
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Comments Button
                        Button {
                            showingComments = true
                        } label: {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.green)
                                // Text("Comments")
                                Text(String(localized: "comments.title", comment: "Title for comments"))
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
        }
    }
    
    @ViewBuilder
    private var bottomToolbar: some View {
        if isEditing {
            Divider()
            HStack {
                // Button("Cancel") {
                Button(String(localized: "common.cancel", comment: "Cancel button")) {
                    cancelEditing()
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)
                
                Spacer()
                
                Button {
                    Task { await saveChanges() }
                } label: {
                    if isUpdating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            // Text("Saving...")
                            Text(String(localized: "common.saving", comment: "Label shown when saving"))
                        }
                    } else {
                        // Text("Save Changes")
                        Text(String(localized: "common.saveChanges", comment: "Title for save changes"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isUpdating)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeEditingState() {
        editedTitle = task.title
        editedDescription = task.description ?? ""
        editedPriority = task.priority
        editedDueDate = task.dueDate
        editedStartDate = task.startDate
        editedEndDate = task.endDate
        editedPercentDone = task.percentDone
        editedColor = task.color
        selectedLabelIds = Set(task.labels?.map { $0.id } ?? [])
        editedRepeatAfter = task.repeatAfter ?? 0
        editedRepeatMode = task.repeatMode
    }
    
    private func startEditing() {
        initializeEditingState()
        isEditing = true
        hasChanges = false
    }
    
    private func cancelEditing() {
        isEditing = false
        hasChanges = false
        initializeEditingState()
    }
    
    private func toggleFavorite() {
        isUpdatingFavorite = true
        Task {
            do {
                var updatedTask = task
                updatedTask.isFavorite.toggle()
                
                let result = try await api.updateTask(updatedTask)
                await MainActor.run {
                    task = result
                    onTaskUpdated(result)
                    isUpdatingFavorite = false
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isUpdatingFavorite = false
                }
            }
        }
    }
    
    @MainActor
    private func saveChanges() async {
        guard hasChanges else {
            isEditing = false
            return
        }
        
        isUpdating = true
        
        do {
            var updatedTask = task
            updatedTask.title = editedTitle
            updatedTask.description = editedDescription.isEmpty ? nil : editedDescription
            updatedTask.priority = editedPriority
            updatedTask.dueDate = editedDueDate
            updatedTask.startDate = editedStartDate
            updatedTask.endDate = editedEndDate
            updatedTask.percentDone = editedPercentDone
            updatedTask.hexColor = editedColor.toHex()
            updatedTask.repeatAfter = editedRepeatAfter > 0 ? editedRepeatAfter : nil
            updatedTask.repeatMode = editedRepeatMode
            
            let result = try await api.updateTask(updatedTask)
            
            // Handle label changes
            await updateTaskLabels(for: result.id)
            
            task = result
            onTaskUpdated(result)
            isEditing = false
            hasChanges = false
            isUpdating = false
            
        } catch {
            updateError = error.localizedDescription
            isUpdating = false
        }
    }
    
    // MARK: - Label Management
    
    private func loadAvailableLabels() async {
        isLoadingLabels = true
        do {
            let labels = try await api.fetchLabels()
            await MainActor.run {
                availableLabels = labels
                isLoadingLabels = false
            }
        } catch {
            await MainActor.run {
                updateError = "Failed to load labels: \(error.localizedDescription)"
                isLoadingLabels = false
            }
        }
    }
    
    private func updateTaskLabels(for taskId: Int) async {
        // Get current label IDs
        let currentLabelIds = Set(task.labels?.map { $0.id } ?? [])
        let newLabelIds = selectedLabelIds
        
        // Find labels to add and remove
        let labelsToAdd = newLabelIds.subtracting(currentLabelIds)
        let labelsToRemove = currentLabelIds.subtracting(newLabelIds)
        
        // Add new labels
        for labelId in labelsToAdd {
            do {
                let updatedTask = try await api.addLabelToTask(taskId: taskId, labelId: labelId)
                await MainActor.run {
                    task = updatedTask
                    onTaskUpdated(updatedTask)
                }
            } catch {
                await MainActor.run {
                    updateError = "Failed to add label: \(error.localizedDescription)"
                }
            }
        }
        
        // Remove labels
        for labelId in labelsToRemove {
            do {
                let updatedTask = try await api.removeLabelFromTask(taskId: taskId, labelId: labelId)
                await MainActor.run {
                    task = updatedTask
                    onTaskUpdated(updatedTask)
                }
            } catch {
                await MainActor.run {
                    updateError = "Failed to remove label: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Reminder Management
    
    private func addReminder(date: Date) async {
        do {
            let updatedTask = try await api.addReminderToTask(taskId: task.id, reminderDate: date)
            await MainActor.run {
                task = updatedTask
                onTaskUpdated(updatedTask)
                // Set next reminder an hour later
                newReminderDate = Date().addingTimeInterval(3600)
            }
        } catch {
            await MainActor.run {
                updateError = "Failed to add reminder: \(error.localizedDescription)"
            }
        }
    }
    
    private func removeReminder(reminderId: Int) async {
        do {
            let updatedTask = try await api.removeReminderFromTask(taskId: task.id, reminderId: reminderId)
            await MainActor.run {
                task = updatedTask
                onTaskUpdated(updatedTask)
            }
        } catch {
            await MainActor.run {
                updateError = "Failed to remove reminder: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Assignee Management
    
    private func removeAssignee(userId: Int) async {
        do {
            let updatedTask = try await api.removeUserFromTask(taskId: task.id, userId: userId)
            await MainActor.run {
                task = updatedTask
                onTaskUpdated(updatedTask)
            }
        } catch {
            await MainActor.run {
                updateError = "Failed to remove assignee: \(error.localizedDescription)"
            }
        }
    }
    
    private func assignUser(_ user: VikunjaUser) async {
        // Check if user is already assigned
        if task.assignees?.contains(where: { $0.id == user.id }) == true {
            return
        }
        
        do {
            let updatedTask = try await api.assignUserToTask(taskId: task.id, userId: user.id)
            await MainActor.run {
                task = updatedTask
                onTaskUpdated(updatedTask)
                showingUserSearch = false
            }
        } catch {
            await MainActor.run {
                updateError = "Failed to assign user: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Repeat Helper Functions
    
    private func formatRepeatDescription() -> String {
        switch editedRepeatMode {
        case .monthly:
            return "monthly"
        case .fromCurrentDate:
            return "from completion date"
        case .afterAmount:
            let value = getRepeatValue()
            let unit = getRepeatUnit()
            let unitText = value == 1 ? String(unit.dropLast()) : unit // Remove 's' for singular
            return "every \(value) \(unitText)"
        }
    }
    
    private func getRepeatValue() -> Int {
        let secondsInDay = 86400
        let secondsInWeek = 604800
        let secondsInMonth = 2592000 // 30 days
        
        if editedRepeatAfter >= secondsInMonth && editedRepeatAfter % secondsInMonth == 0 {
            return editedRepeatAfter / secondsInMonth
        } else if editedRepeatAfter >= secondsInWeek && editedRepeatAfter % secondsInWeek == 0 {
            return editedRepeatAfter / secondsInWeek
        } else {
            return editedRepeatAfter / secondsInDay
        }
    }
    
    private func getRepeatUnit() -> String {
        let secondsInWeek = 604800
        let secondsInMonth = 2592000 // 30 days
        
        if editedRepeatAfter >= secondsInMonth && editedRepeatAfter % secondsInMonth == 0 {
            return "months"
        } else if editedRepeatAfter >= secondsInWeek && editedRepeatAfter % secondsInWeek == 0 {
            return "weeks"
        } else {
            return "days"
        }
    }
    
    private func updateRepeatValue(_ newValue: Int) {
        let unit = getRepeatUnit()
        switch unit {
        case "months":
            editedRepeatAfter = newValue * 2592000 // 30 days
        case "weeks":
            editedRepeatAfter = newValue * 604800
        default:
            editedRepeatAfter = newValue * 86400
        }
    }
    
    private func setRepeatUnit(_ unit: String) {
        let currentValue = getRepeatValue()
        switch unit {
        case "months":
            editedRepeatAfter = currentValue * 2592000 // 30 days
        case "weeks":
            editedRepeatAfter = currentValue * 604800
        default:
            editedRepeatAfter = currentValue * 86400
        }
    }
    
    // MARK: - Sheet Views
    
    @ViewBuilder
    private var labelPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingLabels {
                    VStack {
                        ProgressView(String(localized: "labels.loading", comment: "Loading labels..."))
                        Spacer()
                    }
                } else if availableLabels.isEmpty {
                    VStack {
                        // Text("No labels available")
                        Text(String(localized: "labels.none.available", comment: "Title for no labels available"))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(availableLabels) { label in
                            HStack(spacing: 12) {
                                // Checkmark for selected labels
                                Image(systemName: selectedLabelIds.contains(label.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedLabelIds.contains(label.id) ? .accentColor : .gray)
                                
                                // Color indicator
                                Circle()
                                    .fill(label.color)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                                
                                // Label title
                                Text(label.title)
                                    .font(.body)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedLabelIds.contains(label.id) {
                                    selectedLabelIds.remove(label.id)
                                } else {
                                    selectedLabelIds.insert(label.id)
                                }
                                hasChanges = true
                            }
                        }
                    }
                }
            }
            // .navigationTitle("Select Labels")
            .navigationTitle(String(localized: "tasks.labels.select", comment: "Select labels navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        showingLabelPicker = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var colorPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    colorPreviewSection
                    colorPickerSection
                    presetColorsSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "settings.display.colours.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        showingColorPicker = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var colorPreviewSection: some View {
        VStack(spacing: 8) {
            // Text("Current Color")
            Text(String(localized: "common.colour.current", comment: "Title for current colour"))
                .font(.headline)
            
            Circle()
                .fill(editedColor)
                .frame(width: 60, height: 60)
                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
        }
        .padding(.top)
    }
    
    @ViewBuilder 
    private var colorPickerSection: some View {
        // ColorPicker("Select Color", selection: $editedColor, supportsOpacity: false)
        ColorPicker(
            String(localized: "tasks.colour.select", comment: "Select colour picker"),
            selection: $editedColor,
            supportsOpacity: false
        )
            .labelsHidden()
            .onChange(of: editedColor) { _, _ in
                hasChanges = true
            }
    }
    
    @ViewBuilder
    private var presetColorsSection: some View {
        VStack(spacing: 16) {
            Text(String(localized: "common.colours.preset", comment: "Title for preset colours"))
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                let colors = [
                    Color.red,
                    Color.orange,
                    Color.yellow,
                    Color.green,
                    Color.blue,
                    Color.purple,
                    Color.pink,
                    Color.gray
                ]
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        .onTapGesture {
                            editedColor = color
                            hasChanges = true
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private var remindersEditorSheet: some View {
        NavigationStack {
            VStack {
                if let reminders = task.reminders, !reminders.isEmpty {
                    List {
//                        Section("Current Reminders") {
                        Section(String(localized: "common.reminders.current", comment: "Remove button")) {
                            ForEach(reminders, id: \.id) { reminder in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reminder.reminder, style: .date)
                                            .font(.body)
                                        Text(reminder.reminder, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Button("Remove") {
                                    Button(String(localized: "common.remove", comment: "Remove button")) {
                                        if let reminderId = reminder.id {
                                            Task {
                                                await removeReminder(reminderId: reminderId)
                                            }
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "bell")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        // Text("No Reminders Set")
                        Text(String(localized: "tasks.details.reminders.none.set", comment: "Title for no reminders set"))
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        // Text("Add reminders to get notified about this task")
                        Text(String(localized: "tasks.details.reminders.description",
                                   comment: "Title for add reminders to get notified about this task"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // Add reminder section
                VStack(spacing: 16) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Text("Add New Reminder")
                        Text(String(localized: "tasks.details.reminders.addNew", comment: "Title for add new reminder"))
                            .font(.headline)
                        
                        // DatePicker("Reminder Date", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker(
                            String(localized: "tasks.reminder.date", comment: "Reminder date picker"),
                            selection: $newReminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                    }
                    
                    // Button("Add Reminder") {
                    Button(String(localized: "tasks.details.reminders.add", comment: "Add reminder button")) {
                        Task {
                            await addReminder(date: newReminderDate)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            // .navigationTitle("Reminders")
            .navigationTitle(String(localized: "tasks.reminders.title", comment: "Reminders navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        showingRemindersEditor = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var repeatEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "common.enableRepeat"), isOn: Binding(
                        get: { editedRepeatAfter > 0 },
                        set: { enabled in
                            if enabled {
                                editedRepeatAfter = editedRepeatAfter > 0 ? editedRepeatAfter : 86400 // Default to 1 day
                            } else {
                                editedRepeatAfter = 0
                            }
                            hasChanges = true
                        }
                    ))
                } header: {
                    // Text("Repeat Task")
                    Text(String(localized: "tasks.details.repeat.task", comment: "Title for repeat task"))
                } footer: {
                    if editedRepeatAfter > 0 {
                        Text("tasks.repeat.description \(formatRepeatDescription())",
                                comment: "Message in task details showing repeat schedule e.g. 'every day'")
                    } else {
                        // Text("Task will not repeat")
                        Text(String(localized: "tasks.details.repeat.none", comment: "Title for task will not repeat"))
                    }
                }
                
                if editedRepeatAfter > 0 {
                    // Section("Repeat Mode") {
                    Section(String(localized: "tasks.repeat.mode.section", comment: "Repeat mode section")) {
                        // Picker("Mode", selection: $editedRepeatMode) {
                        Picker(String(localized: "common.mode", comment: "Mode label"), selection: $editedRepeatMode) {
                            ForEach(RepeatMode.allCases) { mode in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.body)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .onChange(of: editedRepeatMode) { _, _ in
                            hasChanges = true
                        }
                    }
                    
                    if editedRepeatMode == .afterAmount {
                        // Section("Repeat Interval") {
                        Section(String(localized: "tasks.repeat.interval", comment: "Repeat interval section")) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Text("Repeat every:")
                                Text(String(localized: "tasks.details.repeat.every", comment: "Label for repeat every"))
                                    .font(.headline)
                                
                                // Time unit picker
                                HStack {
                                    Stepper(value: Binding(
                                        get: { getRepeatValue() },
                                        set: { newValue in
                                            updateRepeatValue(newValue)
                                            hasChanges = true
                                        }
                                    ), in: 1...365, step: 1) {
                                        Text("\(getRepeatValue())")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Picker(String(localized: "tasks.repeat.unit", comment: "Unit"), selection: Binding(
                                        get: { getRepeatUnit() },
                                        set: { unit in
                                            setRepeatUnit(unit)
                                            hasChanges = true
                                        }
                                    )) {
                                        // Text("Days").tag("days")
                                        Text(String(localized: "common.time.days", comment: "Title for days")).tag("days")
                                        // Text("Weeks").tag("weeks") 
                                        Text(String(localized: "common.time.weeks", comment: "Title for weeks")).tag("weeks")
                                        // Text("Months").tag("months")
                                        Text(String(localized: "common.time.months", comment: "Title for months")).tag("months")
                                        // Text("Years").tag("years")
                                        Text(String(localized: "common.time.years", comment: "Title for years")).tag("years")
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            // .navigationTitle("Repeat Settings")
            .navigationTitle(String(localized: "tasks.repeat.settings", comment: "Repeat settings navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        // Reset to original values
                        editedRepeatAfter = task.repeatAfter ?? 0
                        editedRepeatMode = task.repeatMode
                        showingRepeatEditor = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        showingRepeatEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - CommentsContentView
/// A version of CommentsView content without NavigationView wrapper to avoid navigation conflicts
struct CommentsContentView: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let commentCountManager: CommentCountManager?

    @State private var comments: [TaskComment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var newCommentText = ""
    @State private var isAddingComment = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Comments list
            if isLoading && comments.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    // Text("Loading comments...")
                    Text(String(localized: "comments.loading", comment: "Label shown when loading comments"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comments.isEmpty {
                emptyStateView
            } else {
                commentsList
            }
            
            // Add comment section
            addCommentSection
        }
        // .navigationTitle("Comments")
        .navigationTitle(String(localized: "comments.title", comment: "Comments navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Button("Done") {
                Button(String(localized: "common.done", comment: "Done button")) {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadComments()
        }
        .alert(String(localized: "common.error"), isPresented: .constant(error != nil)) {
            // Button("OK") {
            Button(String(localized: "common.ok", comment: "OK button")) { error = nil }
        } message: {
            if let error { Text(error) }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            // Text("No comments yet")
            Text(String(localized: "comments.empty.title", comment: "Title shown when there are no comments"))
                .font(.headline)
            
            // Text("Be the first to add a comment to this task")
            Text(String(localized: "comments.empty.action", comment: "Title shown when there are no comments"))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var commentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(comments) { comment in
                    commentRow(comment: comment)
                }
            }
            .padding()
        }
    }
    
    private func commentRow(comment: TaskComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.author.displayName.isEmpty ? "Unknown" : comment.author.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(comment.created, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.comment)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var addCommentSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(alignment: .top, spacing: 12) {
                // TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                TextField(String(localized: "comments.add.placeholder",
                                comment: "Placeholder for adding a comment"), text: $newCommentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...6)
                
                Button {
                    guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    addComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty ? .secondary : .accentColor)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func loadComments() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedComments = try await api.getTaskComments(taskId: task.id)
                await MainActor.run {
                    comments = fetchedComments.sorted { $0.created < $1.created }
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
    
    private func addComment() {
        let commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentText.isEmpty else { return }
        
        isAddingComment = true
        
        Task {
            do {
                let newComment = try await api.addTaskComment(taskId: task.id, comment: commentText)
                await MainActor.run {
                    comments.append(newComment)
                    comments.sort { $0.created < $1.created }
                    newCommentText = ""
                    isAddingComment = false
                    
                    // Update comment count
                    commentCountManager?.incrementCommentCount(for: task.id)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isAddingComment = false
                }
            }
        }
    }
}
