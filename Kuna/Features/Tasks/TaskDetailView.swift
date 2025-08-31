// Features/Tasks/TaskDetailView.swift
import SwiftUI
import EventKit
import os

struct TaskDetailView: View {
    @State private var task: VikunjaTask
    let api: VikunjaAPI
    let onUpdate: ((VikunjaTask) -> Void)?
    @StateObject private var commentCountManager: CommentCountManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @StateObject private var settings = AppSettings.shared
    @StateObject private var calendarSync = CalendarSyncService.shared

    @State private var isEditing = false
    @State private var hasChanges = false
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var isUpdatingFavorite = false
    @State private var refreshID = UUID()

    // Editing state
    @State private var editedDescription = ""
    @State private var availableLabels: [Label] = []
    @State private var showingLabelPicker = false

    // Section collapse states
    @State private var isTaskInfoExpanded = true
    @State private var isSchedulingExpanded = true
    @State private var isOrganizationExpanded = true
    @State private var isAssigneeExpanded = true
    @State private var isStatusExpanded = true

    @State private var isCalendarSyncExpanded = true
    @State private var isAttachmentsExpanded = true
    @State private var isCommentsExpanded = true

    // “Has time” toggles for each date field
    @State private var startHasTime = false
    @State private var dueHasTime = false
    @State private var endHasTime = false

    // Other picker states
    @State private var showPriorityPicker = false
    @State private var showProgressSlider = false

    // Sheets/editors
    @State private var showingRemindersEditor = false
    @State private var showingRepeatEditor = false
    @State private var selectedLabelIds: Set<Int> = []
    
    // WORKAROUND: Separate state for repeat values to bypass mutation issue
    @State private var taskRepeatAfter: Int? = nil
    @State private var taskRepeatMode: RepeatMode = .afterAmount

    // Editing buffers for dates (decouple from task while editing)
    @State private var editStartDate: Date?
    @State private var editDueDate: Date?
    @State private var editEndDate: Date?

    private let presetColors = [
        Color.red, Color.orange, Color.yellow, Color.green,
        Color.blue, Color.purple, Color.pink, Color.gray
    ]

    init(task: VikunjaTask, api: VikunjaAPI, onUpdate: ((VikunjaTask) -> Void)? = nil) {
        self._task = State(initialValue: task)
        self.api = api
        self.onUpdate = onUpdate
        self._editedDescription = State(initialValue: task.description ?? "")
        self._commentCountManager = StateObject(wrappedValue: CommentCountManager(api: api))
        // Initialize workaround repeat values
        self._taskRepeatAfter = State(initialValue: task.repeatAfter)
        self._taskRepeatMode = State(initialValue: task.repeatMode)
    }
    
    // Helper function to format repeat intervals
    private func formatRepeatInterval(_ seconds: Int) -> String {
        switch seconds {
        case 86400:
            return String(localized: "tasks.repeat.display.daily", comment: "Daily")
        case 604800:
            return String(localized: "tasks.repeat.display.weekly", comment: "Weekly")
        case 2592000:
            return String(localized: "tasks.repeat.display.monthly", comment: "Every 30 days")
        default:
            // Convert to most appropriate unit
            if seconds % 604800 == 0 {
                let weeks = seconds / 604800
                if weeks == 1 {
                    return String(localized: "tasks.repeat.display.weekly", comment: "Weekly")
                } else {
                    return String(localized: "tasks.repeat.display.everyXWeeks", comment: "Every X weeks")
                        .replacingOccurrences(of: "X", with: "\(weeks)")
                }
            } else if seconds % 86400 == 0 {
                let days = seconds / 86400
                if days == 1 {
                    return String(localized: "tasks.repeat.display.daily", comment: "Daily")
                } else {
                    return String(localized: "tasks.repeat.display.everyXDays", comment: "Every X days")
                        .replacingOccurrences(of: "X", with: "\(days)")
                }
            } else if seconds % 3600 == 0 {
                let hours = seconds / 3600
                if hours == 1 {
                    return String(localized: "tasks.repeat.display.hourly", comment: "Hourly")
                } else {
                    return String(localized: "tasks.repeat.display.everyXHours", comment: "Every X hours")
                        .replacingOccurrences(of: "X", with: "\(hours)")
                }
            } else {
                // Fallback - show in days with decimal
                let days = Double(seconds) / 86400.0
                return String(format: String(localized: "tasks.repeat.display.everyXDaysDecimal",
                                            comment: "Every %.1f days"), days)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // 1. TASK INFO
                        settingsSection(title: "TASK INFO", isExpanded: $isTaskInfoExpanded) {
                            VStack(spacing: 0) {
                                titleRow
                                Divider().padding(.leading, 16)
                                descriptionRow
                            }
                            .settingsCardStyle()
                        }

                        // 2. SCHEDULING
                        settingsSection(title: "SCHEDULING", isExpanded: $isSchedulingExpanded) {
                            VStack(spacing: 0) {
                                startDateRow
                                Divider().padding(.leading, 50)
                                dueDateRow
                                Divider().padding(.leading, 50)
                                endDateRow
                                Divider().padding(.leading, 16)
                                remindersRow
                                Divider().padding(.leading, 16)
                                repeatRow
                            }
                            .settingsCardStyle()
                        }

                        // 3. ORGANIZATION
                        settingsSection(title: "ORGANIZATION", isExpanded: $isOrganizationExpanded) {
                            VStack(spacing: 0) {
                                labelsRow
                                Divider().padding(.leading, 16)
                                colorRow
                            }
                            .settingsCardStyle()
                        }

                        // 4. ASSIGNEES
                        if appState.canManageUsers || !(task.assignees?.isEmpty ?? true) || task.createdBy != nil {
                            settingsSection(title: "ASSIGNEES", isExpanded: $isAssigneeExpanded) {
                                TaskAssigneeView(
                                    task: $task,
                                    api: api,
                                    canManageUsers: appState.canManageUsers,
                                    isEditing: isEditing
                                )
                                .settingsCardStyle()
                            }
                        }

                        // 5. STATUS
                        settingsSection(title: "STATUS", isExpanded: $isStatusExpanded) {
                            VStack(spacing: 0) {
                                priorityRow
                                Divider().padding(.leading, 16)
                                progressRow
                            }
                            .settingsCardStyle()
                        }

                        // 6. CALENDAR SYNC (status-only; saves auto-sync now)
                        if settings.calendarSyncEnabled {
                            settingsSection(title: "CALENDAR SYNC", isExpanded: $isCalendarSyncExpanded) {
                                calendarSyncStatusRow
                                    .settingsCardStyle()
                            }
                        }

                        // 6. ATTACHMENTS
                        settingsSection(title: "ATTACHMENTS", isExpanded: $isAttachmentsExpanded) {
                            AttachmentsView(task: task, api: api)
                                .settingsCardStyle()
                        }

                        // 7. RELATED TASKS
                        settingsSection(title: "RELATED TASKS", isExpanded: .constant(true)) {
                            RelatedTasksButtonView(task: $task, api: api)
                                .settingsCardStyle()
                        }

                        // 7. COMMENTS
                        settingsSection(title: "COMMENTS", isExpanded: $isCommentsExpanded) {
                            CommentsButtonView(task: task, api: api, commentCountManager: commentCountManager)
                                .settingsCardStyle()
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))

                if isEditing && hasChanges {
                    saveBar
                }
            }
            .id(refreshID) // Force view refresh when ID changes
            .navigationTitle(String(localized: "tasks.details.title", comment: "Task Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: toggleFavorite) {
                            Image(systemName: task.isFavorite ? "star.fill" : "star")
                                .foregroundColor(task.isFavorite ? .yellow : .gray)
                        }
                        .disabled(isUpdatingFavorite)

                        Button(isEditing ? String(localized: "common.done", comment: "Done button")
                                         : String(localized: "common.edit", comment: "Edit button")) {
                            if isEditing && hasChanges {
                                Task { await saveChanges() }
                            } else {
                                isEditing.toggle()
                                if isEditing {
                                    // Seed editing buffers and flags from current task
                                    editedDescription = task.description ?? ""
                                    editStartDate = task.startDate
                                    editDueDate   = task.dueDate
                                    editEndDate   = task.endDate
                                    startHasTime = hasTime(editStartDate)
                                    dueHasTime   = hasTime(editDueDate)
                                    endHasTime   = hasTime(editEndDate)
                                }
                            }
                        }
                    }
                }
            })
        }
        .onAppear {
            // Initialize edit buffers
            editStartDate = task.startDate
            editDueDate = task.dueDate
            editEndDate = task.endDate
            
            startHasTime = hasTime(task.startDate)
            dueHasTime   = hasTime(task.dueDate)
            endHasTime   = hasTime(task.endDate)
        }
        .onChange(of: task.id) { _, _ in
            // Reset all state when switching to a different task
            isEditing = false
            hasChanges = false
            editedDescription = task.description ?? ""
            startHasTime = hasTime(task.startDate)
            dueHasTime   = hasTime(task.dueDate)
            endHasTime   = hasTime(task.endDate)
            editStartDate = task.startDate
            editDueDate   = task.dueDate
            editEndDate   = task.endDate
        }
        .onDisappear {
            isEditing = false
            hasChanges = false
        }
        // Labels picker
        .sheet(isPresented: $showingLabelPicker) {
            LabelPickerSheet(
                availableLabels: availableLabels,
                initialSelected: Set(task.labels?.map { $0.id } ?? []),
                onCommit: { newSelected in
                    Task {
                        let current = Set(task.labels?.map { $0.id } ?? [])
                        let toAdd = newSelected.subtracting(current)
                        let toRemove = current.subtracting(newSelected)
                        do {
                            for id in toAdd { task = try await api.addLabelToTask(taskId: task.id, labelId: id) }
                            for id in toRemove { task = try await api.removeLabelFromTask(taskId: task.id, labelId: id) }
                            onUpdate?(task)
                            if settings.calendarSyncEnabled && hasTaskDates {
                                await syncTaskToCalendarDirect(task)
                            }
                        } catch {
                            updateError = error.localizedDescription
                        }
                        showingLabelPicker = false
                    }
                },
                onCancel: { showingLabelPicker = false }
            )
        }
        .sheet(isPresented: $showingRemindersEditor) {
            RemindersEditorSheet(
                task: task,
                api: api,
                onUpdated: { updated in
                    task = updated
                    onUpdate?(updated)
                },
                onClose: { showingRemindersEditor = false }
            )
        }
        .sheet(isPresented: $showingRepeatEditor) {
            RepeatEditorSheet(
                repeatAfter: taskRepeatAfter,  // Use workaround state
                repeatMode: taskRepeatMode,     // Use workaround state
                onCommit: { newAfter, newMode in
                    Log.app.debug("RepeatEditorSheet onCommit - newAfter: \(newAfter?.description ?? "nil", privacy: .public)")
                    Log.app.debug("RepeatEditorSheet onCommit - newMode: \(newMode.displayName, privacy: .public)")
                    Log.app.debug("BEFORE - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
                    Log.app.debug("BEFORE - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")

                    // WORKAROUND: Update the separate state variables
                    taskRepeatAfter = newAfter
                    taskRepeatMode = newMode

                    Log.app.debug("AFTER - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
                    Log.app.debug("AFTER - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")

                    // Also try to update task (even though we know it fails)
                    task.repeatAfter = newAfter
                    task.repeatMode = newMode
                    Log.app.debug("Task (wrong) - repeatAfter: \(task.repeatAfter?.description ?? "nil", privacy: .public)")
                    Log.app.debug("Task (wrong) - repeatMode: \(task.repeatMode.displayName, privacy: .public)")
                    
                    hasChanges = true
                    showingRepeatEditor = false
                },
                onCancel: { showingRepeatEditor = false }
            )
        }
    }

    // MARK: - Rows

    private var titleRow: some View {
        HStack {
            Text(String(localized: "common.title", comment: "Title"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField(String(localized: "tasks.placeholder.title", comment: "Task title"), text: $task.title)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onChange(of: task.title) { _, _ in hasChanges = true }
            } else {
                Text(task.title).foregroundColor(.secondary).multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var descriptionRow: some View {
        HStack(alignment: .top) {
            Text(String(localized: "tasks.details.description.title", comment: "Description"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField(String(localized: "tasks.detail.description.placeholder", comment: "Description"),
                          text: $editedDescription, axis: .vertical)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .lineLimit(1...4)
                    .onChange(of: editedDescription) { _, _ in hasChanges = true }
            } else {
                Text(task.description ?? "No description")
                    .foregroundColor(task.description == nil ? .secondary.opacity(0.6) : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // --- Scheduling rows with Date-only / Date & Time support ---

    private var startDateRow: some View {
        editableDateRow(
            title: String(localized: "tasks.startDate", comment: "Start date"),
            date: isEditing ? $editStartDate : Binding.constant(editStartDate),
            hasTime: $startHasTime,
            taskId: task.id
        )
    }

    private var dueDateRow: some View {
        editableDateRow(
            title: String(localized: "tasks.detail.dueDate", comment: "Due date"),
            date: isEditing ? $editDueDate : Binding.constant(editDueDate),
            hasTime: $dueHasTime,
            taskId: task.id
        )
    }

    private var endDateRow: some View {
        editableDateRow(
            title: String(localized: "tasks.detail.endDate", comment: "End date"),
            date: isEditing ? $editEndDate : Binding.constant(editEndDate),
            hasTime: $endHasTime,
            taskId: task.id
        )
    }

    /// Binds to local edit buffers while editing; read-only shows the task values.
    private func editableDateRow(
        title: String,
        date: Binding<Date?>,
        hasTime: Binding<Bool>,
        taskId: Int
    ) -> some View {
        let pickerBinding = Binding<Date>(
            get: { date.wrappedValue ?? Date() },
            set: { newVal in
                if hasTime.wrappedValue {
                    date.wrappedValue = newVal
                } else {
                    date.wrappedValue = Calendar.current.startOfDay(for: newVal)
                }
                hasChanges = true
            }
        )

        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                    .font(.body)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                if isEditing, date.wrappedValue != nil {
                    Button {
                        date.wrappedValue = nil
                        hasChanges = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if isEditing {
                if date.wrappedValue != nil {
                    Picker("", selection: hasTime) {
                        Text(String(localized: "common.date", comment: "Date")).tag(false)
                        Text(String(localized: "common.dateAndTime", comment: "Date & time")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: hasTime.wrappedValue) { _, includeTime in
                        if var d = date.wrappedValue {
                            if !includeTime { d = d.startOfDayLocal }
                            date.wrappedValue = d
                            hasChanges = true
                        }
                    }

                    DatePicker(
                        "",
                        selection: pickerBinding,
                        displayedComponents: hasTime.wrappedValue ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    // Stable identity across task & mode only
                    .id("\(taskId)-\(title)-\(hasTime.wrappedValue ? "dt" : "d")")
                } else {
                    Button {
                        hasTime.wrappedValue = false
                        date.wrappedValue = Date().startOfDayLocal
                        hasChanges = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.accentColor)
                            Text("add.title \(title)", comment: "Add title")
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Spacer()
                    if let d = date.wrappedValue {
                        if hasTime.wrappedValue {
                            Text(d.formatted(date: .abbreviated, time: .shortened)).foregroundColor(.secondary)
                        } else {
                            Text(d.formatted(date: .abbreviated, time: .omitted)).foregroundColor(.secondary)
                        }
                    } else {
                        Text(String(localized: "common.notSet", comment: "Not set"))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var remindersRow: some View {
        HStack {
            Text(String(localized: "tasks.details.reminders.title", comment: "Reminders"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if let reminders = task.reminders, !reminders.isEmpty {
                Text(verbatim: "\(reminders.count)").foregroundColor(.secondary)
            } else {
                Text(String(localized: "common.none", comment: "None")).foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.6)).font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { if isEditing { showingRemindersEditor = true } }
    }

    private var repeatRow: some View {
        HStack {
            Text(String(localized: "tasks.details.repeat.title", comment: "Repeat"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if let repeatAfter = taskRepeatAfter, repeatAfter > 0 {
                Text(formatRepeatInterval(repeatAfter)).foregroundColor(.secondary)
            } else {
                Text(String(localized: "common.never", comment: "Never")).foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.6)).font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                showingRepeatEditor = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var labelsRow: some View {
        HStack(alignment: .center) {
            Text(String(localized: "labels.title", comment: "Labels"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if let labels = task.labels, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(3)) { label in
                        Text(label.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(label.color.opacity(0.2))
                            .foregroundColor(label.color)
                            .cornerRadius(10)
                    }
                    if labels.count > 3 {
                        Text(verbatim: "+\(labels.count - 3)").font(.caption).foregroundColor(.secondary.opacity(0.6))
                    }
                }
            } else {
                Text(String(localized: "common.none", comment: "None")).foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.6)).font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                showingLabelPicker = true
                Task { await loadAvailableLabels() }
            }
        }
    }

    private var colorRow: some View {
        HStack {
            Text(String(localized: "common.colour", comment: "Colour")).font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(task.color == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture { task.hexColor = color.toHex(); hasChanges = true }
                    }
                }
            } else {
                Circle()
                    .fill(task.color)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var priorityRow: some View {
        HStack {
            Text(String(localized: "tasks.detail.priority.title", comment: "Priority"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                Picker(String(localized: "tasks.detail.priority.title", comment: "Priority"), selection: $task.priority) {
                    ForEach(TaskPriority.allCases) { p in
                        HStack {
                            Image(systemName: p.systemImage).foregroundColor(p.color)
                            Text(p.displayName)
                        }.tag(p)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: task.priority) { _, _ in hasChanges = true }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: task.priority.systemImage).foregroundColor(task.priority.color).font(.body)
                    Text(task.priority.displayName).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var progressRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "tasks.detail.progress.title", comment: "Progress"))
                    .font(.body).fontWeight(.medium)
                Spacer()
                Text(verbatim: "\(Int(task.percentDone * 100))%").foregroundColor(.secondary)
            }
            if isEditing {
                Slider(value: Binding(
                    get: { task.percentDone },
                    set: { v in task.percentDone = v; hasChanges = true }
                ), in: 0...1, step: 0.05)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Calendar sync status row

    private var calendarSyncStatusRow: some View {
        HStack {
            Image(systemName: "calendar").foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                if hasTaskDates {
                    Text(String(localized: "tasks.sync.autoSave", comment: "Auto sync on save"))
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text(String(localized: "tasks.sync.needBothDates", comment: "Needs both start and end dates"))
                        .font(.caption).foregroundColor(.orange)
                }
            }
            Spacer()
            Image(systemName: hasTaskDates ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(hasTaskDates ? .green : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 16)
            HStack {
                Button(String(localized: "common.cancel", comment: "Cancel")) {
                    // Discard edits by resetting buffers/flags to current task
                    editStartDate = task.startDate
                    editDueDate   = task.dueDate
                    editEndDate   = task.endDate
                    editedDescription = task.description ?? ""
                    startHasTime = hasTime(task.startDate)
                    dueHasTime   = hasTime(task.dueDate)
                    endHasTime   = hasTime(task.endDate)
                    isEditing = false
                    hasChanges = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Spacer()

                Button {
                    Task { await saveChanges() }
                } label: {
                    HStack(spacing: 8) {
                        if isUpdating { ProgressView().scaleEffect(0.8) }
                        Text(String(localized: "common.save", comment: "Save")).fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Save / API

    private var hasTaskDates: Bool {
        // Only sync if task has BOTH start and end dates
        task.startDate != nil && task.endDate != nil
    }

    private func saveChanges() async {
        isUpdating = true
        defer { isUpdating = false }

        // Move buffered edits into the task
        task.description = editedDescription.isEmpty ? nil : editedDescription

        let _ = Log.app.debug("🔍 Processing edit buffers:")
        let _ = Log.app.debug("  - editStartDate: \(editStartDate?.description ?? "nil") (hasTime: \(startHasTime))")
        let _ = Log.app.debug("  - editDueDate: \(editDueDate?.description ?? "nil") (hasTime: \(dueHasTime))")
        let _ = Log.app.debug("  - editEndDate: \(editEndDate?.description ?? "nil") (hasTime: \(endHasTime))")
        Log.app.debug("Using workaround repeat - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
        Log.app.debug("Using workaround repeat - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")

        // Create a completely new task instance to send to API using workaround values
        let taskToSave = VikunjaTask(
            id: task.id,
            title: task.title,
            description: task.description,
            done: task.done,
            dueDate: editDueDate,
            startDate: editStartDate,
            endDate: editEndDate,
            labels: task.labels,
            reminders: task.reminders,
            priority: task.priority,
            percentDone: task.percentDone,
            hexColor: task.hexColor,
            repeatAfter: taskRepeatAfter,
            repeatMode: taskRepeatMode,
            assignees: task.assignees,
            createdBy: task.createdBy,
            projectId: task.projectId,
            isFavorite: task.isFavorite,
            attachments: task.attachments,
            commentCount: task.commentCount,
            updatedAt: task.updatedAt,
            relations: task.relations
        )
        
        Log.app.debug("Created new task instance with dates")
        Log.app.debug("taskToSave dates - start: \(taskToSave.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("taskToSave dates - due: \(taskToSave.dueDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("taskToSave dates - end: \(taskToSave.endDate?.description ?? "nil", privacy: .public)")

        do {
            Log.app.debug("Saving task \(taskToSave.id, privacy: .public) with updated dates")
            Log.app.debug("Saving task with repeat: after=\(taskToSave.repeatAfter?.description ?? "nil", privacy: .public)")
            Log.app.debug("Saving task with repeat mode: \(taskToSave.repeatMode.displayName, privacy: .public)")

            // Test what gets encoded
            if let encoded = try? JSONEncoder.vikunja.encode(taskToSave),
               let jsonString = String(data: encoded, encoding: .utf8) {
                Log.app.debug("JSON payload being sent to API")
                Log.app.debug("JSON content: \(jsonString, privacy: .private)")
            }

            let updatedTask = try await api.updateTask(taskToSave)

            Log.app.debug("Task saved successfully")
            Log.app.debug("API response dates - start: \(updatedTask.startDate?.description ?? "nil", privacy: .public)")
            Log.app.debug("API response dates - due: \(updatedTask.dueDate?.description ?? "nil", privacy: .public)")
            Log.app.debug("API response dates - end: \(updatedTask.endDate?.description ?? "nil", privacy: .public)")
            Log.app.debug("API returned repeat: after=\(updatedTask.repeatAfter?.description ?? "nil", privacy: .public)")
            Log.app.debug("API returned repeat mode: \(updatedTask.repeatMode.displayName, privacy: .public)")

            // Update the edit buffers FIRST (these are what get displayed)
            editStartDate = updatedTask.startDate
            editDueDate = updatedTask.dueDate
            editEndDate = updatedTask.endDate
            editedDescription = updatedTask.description ?? ""

            // Trigger calendar sync after task update (skip bidirectional to avoid overwriting)
            if settings.calendarSyncEnabled {
                Log.app.debug("Triggering one-way calendar sync after task update")
                calendarSync.setAPI(api)
                await calendarSync.syncAfterTaskUpdate()
            }
            
            // Then update the task
            task = updatedTask
            // Also update our workaround variables to stay in sync
            taskRepeatAfter = updatedTask.repeatAfter
            taskRepeatMode = updatedTask.repeatMode
            
            hasChanges = false
            isEditing = false
            
            // Force a complete view refresh
            await MainActor.run {
                refreshID = UUID()
            }
            
            // Notify the parent view of the update
            onUpdate?(task)
        } catch {
            Log.app.error("Failed to save task: \(String(describing: error), privacy: .public)")
            updateError = error.localizedDescription
        }
    }

    private func reloadTask() async {
        do {
            task = try await api.getTask(taskId: task.id)
            editedDescription = task.description ?? ""
            hasChanges = false
            startHasTime = hasTime(task.startDate)
            dueHasTime   = hasTime(task.dueDate)
            endHasTime   = hasTime(task.endDate)
            if isEditing {
                editStartDate = task.startDate
                editDueDate   = task.dueDate
                editEndDate   = task.endDate
            }
        } catch {
            updateError = error.localizedDescription
        }
    }

    private func loadAvailableLabels() async {
        do { availableLabels = try await api.fetchLabels() }
        catch {
            Log.app.error("Failed to load labels: \(String(describing: error))")
        }
    }

    private func toggleFavorite() {
        isUpdatingFavorite = true
        Task {
            do {
                let updatedTask = try await api.toggleTaskFavorite(task: task)
                await MainActor.run {
                    task = updatedTask
                    isUpdatingFavorite = false
                    onUpdate?(task)
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isUpdatingFavorite = false
                }
            }
        }
    }
    
    // MARK: - Direct Calendar Sync
    
    private func syncTaskToCalendarDirect(_ task: VikunjaTask) async {
        // Only proceed if calendar sync is enabled and we have permission
        guard settings.calendarSyncEnabled else {
            Log.app.debug("Calendar sync disabled")
            return
        }

        // Create a fresh EventStore for this operation to avoid caching issues
        let eventStore = EKEventStore()

        let hasAccess: Bool = {
            if #available(iOS 17.0, *) {
                return EKEventStore.authorizationStatus(for: .event) == .fullAccess
            } else {
                return EKEventStore.authorizationStatus(for: .event) == .authorized
            }
        }()

        guard hasAccess else {
            Log.app.debug("No calendar access")
            return
        }

        // Get the calendar to sync to - find it by identifier in our fresh eventStore
        guard let selectedCalendarId = calendarSync.selectedCalendar?.calendarIdentifier else {
            Log.app.debug("No selected calendar")
            return
        }

        guard let calendar = eventStore.calendar(withIdentifier: selectedCalendarId) else {
            Log.app.debug("Could not find calendar with ID: \(selectedCalendarId, privacy: .public)")
            return
        }

        Log.app.debug("Syncing task \(task.id, privacy: .public): '\(task.title, privacy: .public)'")
        Log.app.debug("Task dates - start: \(task.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Task dates - due: \(task.dueDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Task dates - end: \(task.endDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Task timestamps - start: \(task.startDate?.timeIntervalSince1970 ?? 0, privacy: .public)")
        Log.app.debug("Task timestamps - end: \(task.endDate?.timeIntervalSince1970 ?? 0, privacy: .public)")
        
        // Only sync tasks that have BOTH start and end dates
        let hasRequiredDates = task.startDate != nil && task.endDate != nil
        
        if hasRequiredDates {
            // Find existing event or create new one
            if let existingEvent = findExistingEventDirect(for: task, in: calendar, using: eventStore) {
                Log.app.debug("Found existing event, will delete and recreate")
                // Delete the old event
                do {
                    try eventStore.remove(existingEvent, span: .thisEvent, commit: true)
                    Log.app.debug("Deleted old event")
                } catch {
                    Log.app.error("Failed to delete old event: \(String(describing: error), privacy: .public)")
                }
                // Create a new event with updated dates
                await createCalendarEventDirect(for: task, in: calendar, using: eventStore)
            } else {
                Log.app.debug("No existing event found, creating new")
                await createCalendarEventDirect(for: task, in: calendar, using: eventStore)
            }
        } else {
            Log.app.debug("Task missing required dates, removing calendar event if exists")
            // Remove calendar event if task doesn't have both required dates
            if let existingEvent = findExistingEventDirect(for: task, in: calendar, using: eventStore) {
                await removeCalendarEventDirect(existingEvent, using: eventStore)
            }
        }
    }
    
    private func findExistingEventDirect(for task: VikunjaTask,
                                         in calendar: EKCalendar,
                                         using eventStore: EKEventStore) -> EKEvent? {
        let window = DateInterval(start: Date().addingTimeInterval(-365*24*60*60),
                                  end: Date().addingTimeInterval(365*24*60*60))
        let predicate = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        Log.app.debug("Searching for event with URL: kuna://task/\(task.id, privacy: .public)")
        Log.app.debug("Found \(events.count, privacy: .public) events in calendar")

        let matchingEvent = events.first { event in
            guard let url = event.url?.absoluteString else { return false }
            let matches = url == "kuna://task/\(task.id)" || url.hasPrefix("kuna://task/\(task.id)?")
            if matches {
                Log.app.debug("Found matching event with ID: \(event.eventIdentifier, privacy: .public)")
            }
            return matches
        }
        
        return matchingEvent
    }
    
    private func createCalendarEventDirect(for task: VikunjaTask, in calendar: EKCalendar, using eventStore: EKEventStore) async {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = task.title
        event.notes = task.description
        event.url = URL(string: "kuna://task/\(task.id)")
        
        // Calculate dates with proper priority: endDate > dueDate > startDate
        let (startDate, endDate) = calculateEventDatesDirect(for: task)
        event.startDate = startDate
        event.endDate = endDate
        
        // Add priority to notes if set
        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            event.notes = (event.notes ?? "") + priorityNote
        }
        
        // Add reminders as alarms
        if let reminders = task.reminders, !reminders.isEmpty {
            event.alarms = reminders.map { EKAlarm(absoluteDate: $0.reminder) }
        }
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            Log.app.error("Failed to create calendar event: \(String(describing: error), privacy: .public)")
        }
    }
    
    private func updateCalendarEventDirect(_ event: EKEvent, with task: VikunjaTask, using eventStore: EKEventStore) async {
        Log.app.debug("Updating event - current start: \(event.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Updating event - current end: \(event.endDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Event identifier: \(event.eventIdentifier, privacy: .public)")

        // Use the event directly - don't refresh as it might be a different instance
        let eventToUpdate = event

        eventToUpdate.title = task.title
        eventToUpdate.notes = task.description

        // Calculate dates with proper priority: endDate > dueDate > startDate
        let (startDate, endDate) = calculateEventDatesDirect(for: task)
        Log.app.debug("New calculated dates: start=\(startDate, privacy: .public), end=\(endDate, privacy: .public)")

        // Force the dates to update
        eventToUpdate.startDate = startDate
        eventToUpdate.endDate = endDate

        Log.app.debug("Event dates after setting - start: \(eventToUpdate.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("Event dates after setting - end: \(eventToUpdate.endDate?.description ?? "nil", privacy: .public)")
        
        // Handle priority note without duplicating it
        var baseNotes = (eventToUpdate.notes ?? "")
        baseNotes = baseNotes.replacingOccurrences(
            of: #"\n\[Priority:.*\]$"#,
            with: "",
            options: .regularExpression
        )
        
        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            eventToUpdate.notes = baseNotes + priorityNote
        } else {
            eventToUpdate.notes = baseNotes
        }
        
        // Update reminders
        if let reminders = task.reminders, !reminders.isEmpty {
            eventToUpdate.alarms = reminders.map { EKAlarm(absoluteDate: $0.reminder) }
        } else {
            eventToUpdate.alarms = []
        }
        
        do {
            try eventStore.save(eventToUpdate, span: .thisEvent, commit: true)
            Log.app.debug("Successfully updated calendar event")
            Log.app.debug("Updated event start: \(eventToUpdate.startDate?.description ?? "nil", privacy: .public)")
            Log.app.debug("Updated event end: \(eventToUpdate.endDate?.description ?? "nil", privacy: .public)")
        } catch {
            Log.app.error("Failed to update calendar event: \(String(describing: error), privacy: .public)")
        }
    }
    
    private func removeCalendarEventDirect(_ event: EKEvent, using eventStore: EKEventStore) async {
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            Log.app.error("Failed to remove calendar event: \(String(describing: error), privacy: .public)")
        }
    }
    
    private func calculateEventDatesDirect(for task: VikunjaTask) -> (start: Date, end: Date) {
        // Since we only sync tasks with both start and end dates,
        // we can safely use them directly
        if let taskStart = task.startDate, let taskEnd = task.endDate {
            Log.app.debug("calculateEventDatesDirect: Using task dates - start: \(taskStart, privacy: .public)")
            Log.app.debug("calculateEventDatesDirect: Using task dates - end: \(taskEnd, privacy: .public)")
            return (taskStart, taskEnd)
        }

        // Fallback (shouldn't happen given our new validation)
        let now = Date()
        Log.app.warning("calculateEventDatesDirect: WARNING - Using fallback dates")
        return (now, now.addingTimeInterval(3600))
    }

// MARK: - Sheets
private struct LabelPickerSheet: View {
    let availableLabels: [Label]
    @State var selected: Set<Int>
    let onCommit: (Set<Int>) -> Void
    let onCancel: () -> Void

    init(availableLabels: [Label],
         initialSelected: Set<Int>,
         onCommit: @escaping (Set<Int>) -> Void,
         onCancel: @escaping () -> Void) {
        self.availableLabels = availableLabels
        self._selected = State(initialValue: initialSelected)
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(availableLabels) { label in
                    HStack {
                        Circle().fill(label.color).frame(width: 12, height: 12)
                        Text(label.title)
                        Spacer()
                        if selected.contains(label.id) { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(label.id) { selected.remove(label.id) } else { selected.insert(label.id) }
                    }
                }
            }
            .navigationTitle(String(localized: "tasks.labels.select", comment: "Select labels"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button(String(localized: "common.cancel", comment: "Cancel"), action: onCancel) 
                }
                ToolbarItem(placement: .confirmationAction) { 
                    Button(String(localized: "common.done", comment: "Done")) { onCommit(selected) } 
                }
            }
        }
    }
}

private struct RemindersEditorSheet: View {
    @State var task: VikunjaTask
    let api: VikunjaAPI
    let onUpdated: (VikunjaTask) -> Void
    let onClose: () -> Void
    @State private var error: String?
    @State private var newReminderDate: Date = Date()

    var body: some View {
        NavigationView {
            List {
                if let reminders = task.reminders, !reminders.isEmpty {
                    ForEach(reminders) { r in
                        HStack {
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                            Text(r.reminder.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Button(role: .destructive) { remove(r) } label: { Image(systemName: "trash") }
                        }
                    }
                } else {
                    Text(String(localized: "tasks.detail.reminders.none", comment: "No reminders")).foregroundColor(.secondary)
                }

                Text(String(localized: "common.add", comment: "Add"))
                    .font(.footnote).foregroundStyle(.secondary)
                DatePicker(String(localized: "tasks.reminder", comment: "Reminder"),
                           selection: $newReminderDate,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                Button { addReminder(date: newReminderDate) } label: {
                    SwiftUI.Label(String(localized: "tasks.details.reminders.add", comment: "Add reminder"),
                                  systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle(String(localized: "tasks.reminders.title", comment: "Reminders"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close", comment: "Close"), action: onClose)
                }
            }
            .alert(String(localized: "common.error"), isPresented: .constant(error != nil)) {
                Button(String(localized: "common.ok", comment: "OK")) { error = nil }
            } message: {
                if let error { Text(error) }
            }
        }
    }

    private func addReminder(date: Date) {
        Task {
            do {
                let updated = try await api.addReminderToTask(taskId: task.id, reminderDate: date)
                await MainActor.run { task = updated; onUpdated(updated) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    private func remove(_ reminder: Reminder) {
        guard let id = reminder.id else { return }
        Task {
            do {
                let updated = try await api.removeReminderFromTask(taskId: task.id, reminderId: id)
                await MainActor.run { task = updated; onUpdated(updated) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

private struct RepeatEditorSheet: View {
    enum IntervalUnit: String, CaseIterable {
        case hours = "Hours"
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        
        var seconds: Int {
            switch self {
            case .hours: return 3600
            case .days: return 86400
            case .weeks: return 604800
            case .months: return 2592000 // 30 days approximation
            }
        }
        
        var localizedName: String {
            switch self {
            case .hours: return String(localized: "tasks.repeat.unit.hours", comment: "Hours")
            case .days: return String(localized: "tasks.repeat.unit.days", comment: "Days")
            case .weeks: return String(localized: "tasks.repeat.unit.weeks", comment: "Weeks")
            case .months: return String(localized: "tasks.repeat.unit.months", comment: "Months")
            }
        }
    }
    
    @State private var selectedPreset: String = ""
    @State private var customValue: String = "1"
    @State private var customUnit: IntervalUnit = .days
    @State private var useCustom: Bool = false
    @State var mode: RepeatMode
    
    let onCommit: (Int?, RepeatMode) -> Void
    let onCancel: () -> Void
    
    init(repeatAfter: Int?,
         repeatMode: RepeatMode,
         onCommit: @escaping (Int?, RepeatMode) -> Void,
         onCancel: @escaping () -> Void) {
        self._mode = State(initialValue: repeatMode)
        self.onCommit = onCommit
        self.onCancel = onCancel
        
        // Initialize state based on existing value
        if let seconds = repeatAfter, seconds > 0 {
            // Check if it matches a preset
            switch seconds {
            case 86400:
                self._selectedPreset = State(initialValue: "daily")
                self._useCustom = State(initialValue: false)
            case 604800:
                self._selectedPreset = State(initialValue: "weekly")
                self._useCustom = State(initialValue: false)
            case 2592000:
                self._selectedPreset = State(initialValue: "monthly")
                self._useCustom = State(initialValue: false)
            default:
                // Convert to most appropriate unit
                self._useCustom = State(initialValue: true)
                if seconds % 604800 == 0 {
                    self._customValue = State(initialValue: String(seconds / 604800))
                    self._customUnit = State(initialValue: .weeks)
                } else if seconds % 86400 == 0 {
                    self._customValue = State(initialValue: String(seconds / 86400))
                    self._customUnit = State(initialValue: .days)
                } else if seconds % 3600 == 0 {
                    self._customValue = State(initialValue: String(seconds / 3600))
                    self._customUnit = State(initialValue: .hours)
                } else {
                    // Default to days
                    self._customValue = State(initialValue: String(seconds / 86400))
                    self._customUnit = State(initialValue: .days)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Preset options
                Section(String(localized: "tasks.repeat.presets", comment: "Quick Options")) {
                    HStack(spacing: 12) {
                        PresetButton(
                            title: String(localized: "tasks.repeat.daily", comment: "Daily"),
                            isSelected: selectedPreset == "daily" && !useCustom,
                            action: {
                                selectedPreset = "daily"
                                useCustom = false
                            }
                        )
                        
                        PresetButton(
                            title: String(localized: "tasks.repeat.weekly", comment: "Weekly"),
                            isSelected: selectedPreset == "weekly" && !useCustom,
                            action: {
                                selectedPreset = "weekly"
                                useCustom = false
                            }
                        )
                        
                        PresetButton(
                            title: String(localized: "tasks.repeat.monthly", comment: "Every 30 days"),
                            isSelected: selectedPreset == "monthly" && !useCustom,
                            action: {
                                selectedPreset = "monthly"
                                useCustom = false
                            }
                        )
                    }
                    .padding(.vertical, 8)
                }
                
                // Custom interval
                Section(String(localized: "tasks.repeat.custom", comment: "Custom Interval")) {
                    Toggle(String(localized: "tasks.repeat.useCustom", comment: "Use custom interval"), isOn: $useCustom)
                        .onChange(of: useCustom) { _, newValue in
                            if newValue {
                                selectedPreset = ""
                            }
                        }
                    
                    if useCustom {
                        HStack {
                            Text(String(localized: "tasks.repeat.every", comment: "Every"))
                            TextField("1", text: $customValue)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker(String(localized: "tasks.repeat.unit", comment: "Unit"), selection: $customUnit) {
                                ForEach(IntervalUnit.allCases, id: \.self) { unit in
                                    Text(unit.localizedName).tag(unit)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                
                // Repeat mode
                Section(header: Text(String(localized: "tasks.repeat.mode", comment: "Repeat Mode")),
                       footer: Text(mode.description).font(.caption).foregroundColor(.secondary)) {
                    Picker(String(localized: "tasks.repeat.mode.picker", comment: "When to repeat"), selection: $mode) {
                        ForEach(RepeatMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                }
            }
            .navigationTitle(String(localized: "tasks.repeat.title", comment: "Repeat Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", comment: "Done")) {
                        let seconds: Int?
                        
                        if useCustom {
                            // Calculate seconds from custom value
                            if let value = Int(customValue), value > 0 {
                                seconds = value * customUnit.seconds
                            } else {
                                seconds = nil
                            }
                        } else {
                            // Use preset value
                            switch selectedPreset {
                            case "daily": seconds = 86400
                            case "weekly": seconds = 604800
                            case "monthly": seconds = 2592000
                            default: seconds = nil
                            }
                        }
                        
                        onCommit(seconds, mode)
                    }
                }
            }
        }
    }
}

// Helper view for preset buttons
private struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

    // MARK: - Section wrapper

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded.wrappedValue)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }
}

// MARK: - Small helpers

private func hasTime(_ date: Date?) -> Bool {
    guard let d = date else { return false }
    let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: d)
    return (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0 || (comps.second ?? 0) != 0
}

private func dateOrToday(_ date: Date?) -> Date? { date ?? Date().startOfDayLocal }
