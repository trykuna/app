// Features/Tasks/TaskDetailView.swift
import SwiftUI
import EventKit

struct TaskDetailView: View {
    @State private var task: VikunjaTask
    let api: VikunjaAPI
    @StateObject private var commentCountManager: CommentCountManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @StateObject private var settings = AppSettings.shared
    @StateObject private var calendarSync = CalendarSyncService.shared
    @StateObject private var engine = CalendarSyncEngine()   // ✅ new sync engine

    @State private var isEditing = false
    @State private var hasChanges = false
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var isUpdatingFavorite = false

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

    private let presetColors = [
        Color.red, Color.orange, Color.yellow, Color.green,
        Color.blue, Color.purple, Color.pink, Color.gray
    ]

    init(task: VikunjaTask, api: VikunjaAPI) {
        self._task = State(initialValue: task)
        self.api = api
        self._editedDescription = State(initialValue: task.description ?? "")
        self._commentCountManager = StateObject(wrappedValue: CommentCountManager(api: api))
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

                        // 6. ATTACHMENTS Section
                        settingsSection(
                            title: "ATTACHMENTS",
                            isExpanded: $isAttachmentsExpanded
                        ) {
                            AttachmentsView(task: task, api: api)
                                .settingsCardStyle()
                        }


                        // 7. RELATED TASKS
                        settingsSection(
                            title: "RELATED TASKS",
                            isExpanded: .constant(true)
                        ) {
                            RelatedTasksButtonView(task: $task, api: api)
                                .settingsCardStyle()
                        }

                        // 7. COMMENTS Section
                        settingsSection(
                            title: "COMMENTS",
                            isExpanded: $isCommentsExpanded
                        ) {
                            CommentsButtonView(task: task, api: api, commentCountManager: commentCountManager)
                                .settingsCardStyle()
                        }

                        // Bottom padding for save bar
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))

                // Save/Cancel Bar
                if isEditing && hasChanges {
                    saveBar
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: toggleFavorite) {
                            Image(systemName: task.isFavorite ? "star.fill" : "star")
                                .foregroundColor(task.isFavorite ? .yellow : .gray)
                        }
                        .disabled(isUpdatingFavorite)

                        Button(isEditing ? "Done" : "Edit") {
                            if isEditing && hasChanges {
                                Task { await saveChanges() }
                            } else {
                                isEditing.toggle()
                                if isEditing {
                                    editedDescription = task.description ?? ""
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // init calendar engine
            if let api = appState.api as? CalendarSyncAPI {
                engine.setAPI(api)
            }
            // seed “hasTime” flags from existing dates
            startHasTime = hasTime(task.startDate)
            dueHasTime   = !(task.isAllDay) && hasTime(task.dueDate)
            endHasTime   = hasTime(task.endDate)
        }
        // Labels picker
        .sheet(isPresented: $showingLabelPicker) {
            LabelPickerSheet(
                availableLabels: availableLabels,
                initialSelected: Set(task.labels?.map { $0.id } ?? []),
                onCommit: { newSelected in
                    Task {
                        // Compute diffs
                        let current = Set(task.labels?.map { $0.id } ?? [])
                        let toAdd = newSelected.subtracting(current)
                        let toRemove = current.subtracting(newSelected)
                        do {
                            for id in toAdd {
                                task = try await api.addLabelToTask(taskId: task.id, labelId: id)
                            }
                            for id in toRemove {
                                task = try await api.removeLabelFromTask(taskId: task.id, labelId: id)
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
        // Reminders editor
        .sheet(isPresented: $showingRemindersEditor) {
            RemindersEditorSheet(
                task: task,
                api: api,
                onUpdated: { updated in
                    task = updated
                },
                onClose: { showingRemindersEditor = false }
            )
        }
        // Repeat editor
        .sheet(isPresented: $showingRepeatEditor) {
            RepeatEditorSheet(
                repeatAfter: task.repeatAfter,
                repeatMode: task.repeatMode,
                onCommit: { newAfter, newMode in
                    task.repeatAfter = newAfter
                    task.repeatMode = newMode
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
            Text("Title")
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField("Task title", text: $task.title)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onChange(of: task.title) { _, _ in hasChanges = true }
            } else {
                Text(task.title)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var descriptionRow: some View {
        HStack(alignment: .top) {
            Text("Description")
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField("Enter description...", text: $editedDescription, axis: .vertical)
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
            title: "Start Date",
            date: task.startDate,
            hasTime: $startHasTime,
            onChange: { newDate in
                if let d = newDate {
                    task.startDate = startHasTime ? d : d.startOfDayLocal
                } else {
                    task.startDate = nil
                }
                hasChanges = true
            }
        )
    }

    private var dueDateRow: some View {
        editableDateRow(
            title: "Due Date",
            date: task.dueDate,
            hasTime: $dueHasTime,
            onChange: { newDate in
                if let d = newDate {
                    if dueHasTime {
                        task.dueDate = d
                    } else {
                        task.dueDate = d.startOfDayLocal
                    }
                } else {
                    task.dueDate = nil
                }
                hasChanges = true
            }
        )
    }

    private var endDateRow: some View {
        editableDateRow(
            title: "End Date",
            date: task.endDate,
            hasTime: $endHasTime,
            onChange: { newDate in
                if let d = newDate {
                    task.endDate = endHasTime ? d : d.startOfDayLocal
                } else {
                    task.endDate = nil
                }
                hasChanges = true
            }
        )
    }

    /// A date editor that:
    /// - shows an "Add <title>" button when date is nil (no auto-fill to 'now')
    /// - supports Date-only vs Date&Time via a segmented control
    private func editableDateRow(
        title: String,
        date: Date?,
        hasTime: Binding<Bool>,
        onChange: @escaping (Date?) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                    .font(.body)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                if isEditing, date != nil {
                    Button {
                        onChange(nil)
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
                if let date = date {
                    // Mode picker
                    Picker("", selection: hasTime) {
                        Text("Date").tag(false)
                        Text("Date & Time").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: hasTime.wrappedValue) { _, includeTime in
                        if var d = dateOrToday(date) {
                            if !includeTime { d = d.startOfDayLocal }
                            onChange(d)
                        }
                    }

                    // Actual picker
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { date },
                            set: { newVal in
                                var v = newVal
                                if !hasTime.wrappedValue { v = newVal.startOfDayLocal }
                                onChange(v)
                            }
                        ),
                        displayedComponents: hasTime.wrappedValue ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } else {
                    // No date yet: let user add one (default to midnight today)
                    Button {
                        hasTime.wrappedValue = false
                        onChange(Date().startOfDayLocal)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add \(title)")
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
                    if let d = date {
                        if hasTime.wrappedValue {
                            Text(d.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        } else {
                            Text(d.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set").foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var remindersRow: some View {
        HStack {
            Text("Reminders")
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            if let reminders = task.reminders, !reminders.isEmpty {
                Text("\(reminders.count)").foregroundColor(.secondary)
            } else {
                Text("None").foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                showingRemindersEditor = true
            }
        }
    }

    private var repeatRow: some View {
        HStack {
            Text("Repeat")
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
                Text(task.repeatMode.displayName).foregroundColor(.secondary)
            } else {
                Text("Never").foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { showingRepeatEditor = true }
        }
    }

    private var labelsRow: some View {
        HStack(alignment: .center) {
            Text("Labels")
                .font(.body)
                .fontWeight(.medium)
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
                        Text("+\(labels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            } else {
                Text("None").foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
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
            Text("Color").font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(task.color == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                task.hexColor = color.toHex()
                                hasChanges = true
                            }
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
            Text("Priority").font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                Picker("Priority", selection: $task.priority) {
                    ForEach(TaskPriority.allCases) { p in
                        HStack {
                            Image(systemName: p.systemImage).foregroundColor(p.color)
                            Text(p.displayName)
                        }
                        .tag(p)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: task.priority) { _, _ in hasChanges = true }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: task.priority.systemImage)
                        .foregroundColor(task.priority.color)
                        .font(.body)
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
                Text("Progress").font(.body).fontWeight(.medium)
                Spacer()
                Text("\(Int(task.percentDone * 100))%").foregroundColor(.secondary)
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
                    Text("This task will sync automatically on save")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Task has no dates to sync")
                        .font(.caption)
                        .foregroundColor(.orange)
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
            Divider()
                .padding(.leading, 16)
            HStack {
                Button("Cancel") {
                    Task {
                        await reloadTask()
                        isEditing = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Spacer()

                Button {
                    Task { await saveChanges() }
                } label: {
                    HStack(spacing: 8) {
                        if isUpdating { ProgressView().scaleEffect(0.8) }
                        Text("Save").fontWeight(.semibold)
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
        task.startDate != nil || task.dueDate != nil || task.endDate != nil
    }

    private func saveChanges() async {
        isUpdating = true
        defer { isUpdating = false }

        task.description = editedDescription.isEmpty ? nil : editedDescription

        do {
            task = try await api.updateTask(task)
            hasChanges = false
            isEditing = false

            // ✅ Trigger calendar sync automatically (fire-and-forget to avoid blocking UI)
            if settings.calendarSyncEnabled {
                Task { await engine.syncNow(mode: .twoWay) }
            }
        } catch {
            updateError = error.localizedDescription
        }
    }

    private func reloadTask() async {
        do {
            task = try await api.getTask(taskId: task.id)
            editedDescription = task.description ?? ""
            hasChanges = false
            // refresh hasTime flags
            startHasTime = hasTime(task.startDate)
            dueHasTime   = !(task.isAllDay) && hasTime(task.dueDate)
            endHasTime   = hasTime(task.endDate)
        } catch {
            updateError = error.localizedDescription
        }
    }

    private func loadAvailableLabels() async {
        do {
            availableLabels = try await api.fetchLabels()
        } catch {
            print("Failed to load labels: \(error)")
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
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isUpdatingFavorite = false
                }
            }
        }
    }


// MARK: - Sheets
private struct LabelPickerSheet: View {
    let availableLabels: [Label]
    @State var selected: Set<Int>
    let onCommit: (Set<Int>) -> Void
    let onCancel: () -> Void

    init(availableLabels: [Label], initialSelected: Set<Int>, onCommit: @escaping (Set<Int>) -> Void, onCancel: @escaping () -> Void) {
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
            .navigationTitle("Select Labels")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onCommit(selected) } }
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
                // Existing reminders
                if let reminders = task.reminders, !reminders.isEmpty {
                    ForEach(reminders) { r in
                        HStack {
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                            Text(r.reminder.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Button(role: .destructive) { remove(r) } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } else {
                    Text("No reminders").foregroundColor(.secondary)
                }

                // Add new reminder
                Text("Add").font(.footnote).foregroundStyle(.secondary)
                DatePicker("Reminder", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                Button {
                    addReminder(date: newReminderDate)
                } label: {
                    SwiftUI.Label("Add Reminder", systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", action: onClose) }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error { Text(error) }
            }
        }
    }

    private func addReminder(date: Date) {
        Task {
            do {
                let updated = try await api.addReminderToTask(taskId: task.id, reminderDate: date)
                await MainActor.run {
                    task = updated
                    onUpdated(updated)
                }
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
                await MainActor.run {
                    task = updated
                    onUpdated(updated)
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

private struct RepeatEditorSheet: View {
    @State var repeatAfterText: String
    @State var mode: RepeatMode
    let onCommit: (Int?, RepeatMode) -> Void
    let onCancel: () -> Void

    init(repeatAfter: Int?, repeatMode: RepeatMode, onCommit: @escaping (Int?, RepeatMode) -> Void, onCancel: @escaping () -> Void) {
        self._repeatAfterText = State(initialValue: repeatAfter.map(String.init) ?? "")
        self._mode = State(initialValue: repeatMode)
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Mode") {
                    Picker("Repeat Mode", selection: $mode) {
                        ForEach(RepeatMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                }
                Section("Interval (seconds)") {
                    TextField("e.g. 86400 for daily", text: $repeatAfterText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Repeat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let val = Int(repeatAfterText)
                        onCommit(val, mode)
                    }
                }
            }
        }
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

private func dateOrToday(_ date: Date?) -> Date? {
    date ?? Date().startOfDayLocal
}

