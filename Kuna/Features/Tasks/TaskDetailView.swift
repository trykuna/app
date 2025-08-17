// Features/Tasks/TaskDetailView.swift
import SwiftUI
import EventKit

struct TaskDetailView: View {
    @State private var task: VikunjaTask
    let api: VikunjaAPI

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

    // “Has time” toggles for each date field
    @State private var startHasTime = false
    @State private var dueHasTime = false
    @State private var endHasTime = false

    private let presetColors = [
        Color.red, Color.orange, Color.yellow, Color.green,
        Color.blue, Color.purple, Color.pink, Color.gray
    ]

    init(task: VikunjaTask, api: VikunjaAPI) {
        self._task = State(initialValue: task)
        self.api = api
        self._editedDescription = State(initialValue: task.description ?? "")
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
                        task.isAllDay = false
                        task.dueDate = d
                    } else {
                        task.isAllDay = true
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

            // ✅ Trigger calendar sync automatically
            if settings.calendarSyncEnabled {
                await engine.syncNow(mode: .twoWay)
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
