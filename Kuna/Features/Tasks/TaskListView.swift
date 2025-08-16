// Features/Tasks/TaskListView.swift
import SwiftUI

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
    @Published var error: String?
    @Published var isAddingTask = false
    private let api: VikunjaAPI
    private let projectId: Int

    init(api: VikunjaAPI, projectId: Int) {
        self.api = api; self.projectId = projectId
    }

    func load(queryItems: [URLQueryItem] = []) async {
        loading = true; defer { loading = false }
        do {
            if queryItems.isEmpty {
                tasks = try await api.fetchTasks(projectId: projectId)
            } else {
                tasks = try await api.fetchTasks(projectId: projectId, queryItems: queryItems)
            }
            // Write widget cache after successful load
            WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            // Also write to shared file for watch
            SharedFileManager.shared.writeTasks(tasks, for: projectId)
        }
        catch { self.error = error.localizedDescription }
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
            print("TaskListView: Toggling favorite for task \(task.id): \(task.title), current state: \(task.isFavorite)")
            #endif
            let updated = try await api.toggleTaskFavorite(task: task)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                #if DEBUG
                print("TaskListView: Task \(task.id) favorite status changed to: \(updated.isFavorite)")
                #endif
                tasks[i] = updated
                // Update widget cache after favorite change
                WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            }
        } catch {
            #if DEBUG
            print("TaskListView: Error toggling favorite for task \(task.id): \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }

    func createTask(title: String, description: String?) async {
        do {
            let newTask = try await api.createTask(projectId: projectId, title: title, description: description)
            tasks.insert(newTask, at: 0)
            isAddingTask = false
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
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""

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

    var body: some View {
        VStack(spacing: 0) {
            // Project title header
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

                    // Task count badge
                    if !vm.tasks.isEmpty {
                        VStack(spacing: 2) {
                            Text("\(vm.tasks.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(vm.tasks.count == 1 ? "task" : "tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color(.systemBackground))

            Divider()

            // Task list or empty state
            if vm.tasks.isEmpty && !vm.loading {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "checklist")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("No Tasks Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("This project doesn't have any tasks yet. Create your first task to get started!")
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
                            Text("Create First Task")
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

                // Add new task overlay when in adding mode
                if vm.isAddingTask {
                    VStack {
                        Spacer()

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Create New Task")
                                .font(.headline)
                                .fontWeight(.semibold)

                            TextField("Task title", text: $newTaskTitle)
                                .textFieldStyle(.roundedBorder)

                            TextField("Description (optional)", text: $newTaskDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    vm.isAddingTask = false
                                    newTaskTitle = ""
                                    newTaskDescription = ""
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Create Task") {
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
                        // Dismiss when tapping outside
                        vm.isAddingTask = false
                        newTaskTitle = ""
                        newTaskDescription = ""
                    }
                }
            } else {
                // Task list with tasks
                List {
                    // Add new task section
                    if vm.isAddingTask {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Task title", text: $newTaskTitle)
                                    .textFieldStyle(.roundedBorder)

                                TextField("Description (optional)", text: $newTaskDescription, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)

                                HStack {
                                    Button("Cancel") {
                                        vm.isAddingTask = false
                                        newTaskTitle = ""
                                        newTaskDescription = ""
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Add Task") {
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

                    // Existing tasks
                    ForEach(sortedAndGroupedTasks, id: \.0) { sectionTitle, tasks in
                        if let sectionTitle = sectionTitle {
                            Section(header: Text(sectionTitle).font(.caption).fontWeight(.medium).foregroundColor(.secondary).textCase(.uppercase)) {
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
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .foregroundColor(currentFilter.hasActiveFilters ? .accentColor : .primary)

                    Button {
                        showingSort = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.isAddingTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.isAddingTask)
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
                title: Text("Sort Tasks"),
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
                await vm.load(queryItems: query)
            }
        }
        .onChange(of: currentFilter) { _, _ in
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query)
            }
        }
        .onChange(of: settings.defaultSortOption) { _, newSortOption in
            currentSort = newSortOption
        }
        }

    @ViewBuilder
    private func taskRow(for t: VikunjaTask) -> some View {
        NavigationLink(destination: TaskDetailView(task: t, api: api)) {
            HStack {
                Button(action: {
                    Task { await vm.toggle(t) }
                }) {
                    Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(t.done ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())

                // Color ball - only show if task has custom color OR setting allows default colors
                if t.hasCustomColor || settings.showDefaultColorBalls {
                    Circle()
                        .fill(t.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                }

                // Priority icon - only show if not unset
                if t.priority != .unset {
                    Image(systemName: t.priority.systemImage)
                        .foregroundColor(t.priority.color)
                        .font(.body)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(t.title)
                            .strikethrough(t.done)
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    if let labels = t.labels, !labels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(labels) { label in
                                    Text(label.title)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(label.color.opacity(0.2))
                                        .foregroundColor(label.color)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }

                    // Date indicators
                    if t.startDate != nil || t.dueDate != nil || t.endDate != nil {
                        HStack(spacing: 4) {
                            if let startDate = t.startDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    VStack(spacing: 0) {
                                        Text(startDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text(startDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.green.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(3)
                            }

                            if let dueDate = t.dueDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    VStack(spacing: 0) {
                                        Text(dueDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text(dueDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.orange.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(3)
                            }

                            if let endDate = t.endDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    VStack(spacing: 0) {
                                        Text(endDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(endDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.blue.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(3)
                            }
                        }
                    }

                    // Repeat indicator
                    if let repeatAfter = t.repeatAfter, repeatAfter > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            Text(t.repeatMode.displayName)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(3)
                    }

                    // Reminders indicator
                    if let reminders = t.reminders, !reminders.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: reminders.contains(where: { isReminderSoon($0.reminder) }) ? "bell.fill" : "bell")
                                .font(.caption2)
                                .foregroundColor(reminders.contains(where: { isReminderSoon($0.reminder) }) ? .red : .gray)
                            Text("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(3)
                    }

                    // Assignees indicator
                    if let assignees = t.assignees, !assignees.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(assignees.count) assignee\(assignees.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                    }
                }

                Spacer()
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await vm.toggle(t) }
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
                        await vm.load(queryItems: currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []) // Refresh the task list
                    } catch {
                        vm.error = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }

    private func isReminderSoon(_ reminderDate: Date) -> Bool {
        let now = Date()
        let timeDifference = reminderDate.timeIntervalSince(now)
        return timeDifference <= 3600 && timeDifference > 0 // Within 1 hour from now
    }
}
