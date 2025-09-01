// Features/Tasks/TaskDetailView.swift
import SwiftUI
import EventKit
import os

struct TaskDetailView: View {
    @State var task: VikunjaTask
    let api: VikunjaAPI
    let onUpdate: ((VikunjaTask) -> Void)?
    @StateObject private var commentCountManager: CommentCountManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @StateObject var settings = AppSettings.shared
    @StateObject var calendarSync = CalendarSyncService.shared

    @State var isEditing = false
    @State var hasChanges = false
    @State var isUpdating = false
    @State var updateError: String?
    @State private var isUpdatingFavorite = false
    @State var refreshID = UUID()

    // Editing state
    @State var editedDescription = ""
    @State var availableLabels: [Label] = []
    @State var showingLabelPicker = false

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
    @State var startHasTime = false
    @State var dueHasTime = false
    @State var endHasTime = false

    // Other picker states
    @State private var showPriorityPicker = false
    @State private var showProgressSlider = false

    // Sheets/editors
    @State var showingRemindersEditor = false
    @State var showingRepeatEditor = false
    @State private var selectedLabelIds: Set<Int> = []
    
    // WORKAROUND: Separate state for repeat values to bypass mutation issue
    @State var taskRepeatAfter: Int?
    @State var taskRepeatMode: RepeatMode = .afterAmount

    // Editing buffers for dates (decouple from task while editing)
    @State var editStartDate: Date?
    @State var editDueDate: Date?
    @State var editEndDate: Date?

    private let presetColors = [
        Color.red, Color.orange, Color.yellow, Color.green,
        Color.blue, Color.purple, Color.pink, Color.gray
    ]

    init(task: VikunjaTask, api: VikunjaAPI, onUpdate: ((VikunjaTask) -> Void)?) {
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
                                TaskTitleRow(isEditing: isEditing, title: $task.title, hasChanges: $hasChanges)
                                Divider().padding(.leading, 16)
                                TaskDescriptionRow(isEditing: isEditing, editedDescription: $editedDescription, taskDescription: task.description, hasChanges: $hasChanges)
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
                                TaskRemindersRow(isEditing: isEditing, remindersCount: task.reminders?.count ?? 0, onTap: { showingRepeatEditor = true})
                                Divider().padding(.leading, 16)
                                TaskRepeatRow(isEditing: isEditing,
                                              repeatAfter: taskRepeatAfter,
                                              displayText: taskRepeatAfter.flatMap { $0 > 0 ? formatRepeatInterval($0) : nil } ?? "",
                                              onTap: { showingRepeatEditor = true })
                            }
                            .settingsCardStyle()
                        }

                        // 3. ORGANIZATION
                        settingsSection(title: "ORGANIZATION", isExpanded: $isOrganizationExpanded) {
                            VStack(spacing: 0) {
                                TaskLabelsRow(
                                    isEditing: isEditing,
                                    labels: task.labels
                                ) {
                                    showingLabelPicker = true
                                    Task { await loadAvailableLabels() }
                                }
                                Divider().padding(.leading, 16)
                                TaskColorRow(
                                    isEditing: isEditing,
                                    selectedHexColor: $task.hexColor,
                                    displayColor: task.color,
                                    presetColors: presetColors,
                                    hasChanges: $hasChanges
                                )
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
                                TaskPriorityRow(isEditing: isEditing, priority: $task.priority, hasChanges: $hasChanges)
                                Divider().padding(.leading, 16)
                                TaskProgressRow(isEditing: isEditing, percentDone: $task.percentDone, hasChanges: $hasChanges)
                            }
                            .settingsCardStyle()
                        }

                        // 6. CALENDAR SYNC (status-only; saves auto-sync now)
                        if settings.calendarSyncEnabled {
                            settingsSection(title: "CALENDAR SYNC", isExpanded: $isCalendarSyncExpanded) {
                                CalendarSyncStatusRow(hasTaskDates: hasTaskDates)
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
                    SaveBar(
                        isUpdating: isUpdating,
                        onCancel: {
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
                        },
                        onSave: saveChanges
                    )
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
        .background(sheetModifiers)
    }

    // MARK: - Rows

    // --- Scheduling rows with Date-only / Date & Time support ---

    private var startDateRow: some View {
        EditableDateRow(
            title: String(localized: "tasks.startDate", comment: "Start date"),
            date: isEditing ? $editStartDate : Binding.constant(editStartDate),
            hasTime: $startHasTime,
            taskId: task.id,
            isEditing: isEditing,
            hasChanges: $hasChanges
        )
    }

    private var dueDateRow: some View {
        EditableDateRow(
            title: String(localized: "tasks.detail.dueDate", comment: "Due date"),
            date: isEditing ? $editDueDate : Binding.constant(editDueDate),
            hasTime: $dueHasTime,
            taskId: task.id,
            isEditing: isEditing,
            hasChanges: $hasChanges
        )
    }

    private var endDateRow: some View {
        EditableDateRow(
            title: String(localized: "tasks.detail.endDate", comment: "End date"),
            date: isEditing ? $editEndDate : Binding.constant(editEndDate),
            hasTime: $endHasTime,
            taskId: task.id,
            isEditing: isEditing,
            hasChanges: $hasChanges
        )
    }

    var hasTaskDates: Bool {
        // Only sync if task has BOTH start and end dates
        task.startDate != nil && task.endDate != nil
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
        do { 
            availableLabels = try await api.fetchLabels()
        } catch {
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
    
    func syncTaskToCalendarDirect(_ task: VikunjaTask) async {
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
