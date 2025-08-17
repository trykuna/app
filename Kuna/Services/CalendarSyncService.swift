// Services/CalendarSyncService.swift
import Foundation
import EventKit
import SwiftUI

@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    // MARK: - New Engine Integration
    private let syncEngine = CalendarSyncEngine()

    // MARK: - Legacy Properties (for backward compatibility)
    let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isCalendarSyncEnabled: Bool = false
    @Published var selectedCalendar: EKCalendar?
    @Published var syncErrors: [String] = []
    @Published var syncSuccessMessage: String?

    // Track synced events to avoid duplicates
    private var syncedEventIdentifiers: Set<String> = []

    private init() {
        updateAuthorizationStatus()
        loadSettings()
        setupEngineBinding()
    }

    private func setupEngineBinding() {
        // Bind engine state to legacy properties
        syncEngine.$isEnabled.assign(to: &$isCalendarSyncEnabled)
        syncEngine.$syncErrors.assign(to: &$syncErrors)
    }
    
    // MARK: - Authorization
    
    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestCalendarAccess() async -> Bool {
        // Check current status first
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("📅 Calendar access request - Current status: \(currentStatus)")

        switch currentStatus {
        case .fullAccess:
            print("📅 Calendar access: Already have full access")
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return true

        case .authorized:
            // For iOS versions before 17, .authorized is equivalent to full access
            print("📅 Calendar access: Already authorized (legacy)")
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return true

        case .notDetermined:
            // Request permission
            print("📅 Calendar access: Requesting permission...")
            do {
                if #available(iOS 17.0, *) {
                    print("📅 Using iOS 17+ requestFullAccessToEvents")
                    let granted = try await eventStore.requestFullAccessToEvents()
                    print("📅 Permission result: \(granted)")
                    await MainActor.run {
                        updateAuthorizationStatus()
                    }
                    return granted
                } else {
                    // For iOS 16 and earlier
                    print("📅 Using legacy requestAccess")
                    return await withCheckedContinuation { continuation in
                        eventStore.requestAccess(to: .event) { granted, error in
                            print("📅 Legacy permission result: \(granted), error: \(String(describing: error))")
                            Task { @MainActor in
                                self.updateAuthorizationStatus()
                                if let error = error {
                                    self.syncErrors.append("Calendar access error: \(error.localizedDescription)")
                                }
                            }
                            continuation.resume(returning: granted)
                        }
                    }
                }
            } catch {
                print("📅 Calendar access request failed: \(error)")
                await MainActor.run {
                    syncErrors.append("Failed to request calendar access: \(error.localizedDescription)")
                    updateAuthorizationStatus()
                }
                return false
            }

        case .denied, .restricted:
            print("📅 Calendar access: Denied or restricted")
            await MainActor.run {
                syncErrors.append("Calendar access denied. Please enable in Settings > Privacy & Security > Calendars")
                updateAuthorizationStatus()
            }
            return false

        case .writeOnly:
            await MainActor.run {
                syncErrors.append("Calendar access is write-only. Full access required for sync.")
                updateAuthorizationStatus()
            }
            return false

        @unknown default:
            await MainActor.run {
                syncErrors.append("Unknown calendar authorization status")
                updateAuthorizationStatus()
            }
            return false
        }
    }
    
    // MARK: - Calendar Management
    
    func getAvailableCalendars() -> [EKCalendar] {
        if #available(iOS 17.0, *) {
            guard authorizationStatus == .fullAccess else { return [] }
        } else {
            guard authorizationStatus == .authorized else { return [] }
        }
        return eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
    }
    
    func setSelectedCalendar(_ calendar: EKCalendar?) {
        selectedCalendar = calendar
        saveSettings()
    }
    
    // MARK: - Sync Operations
    
    func syncTaskToCalendar(_ task: VikunjaTask) async -> Bool {
        let hasAccess: Bool
        if #available(iOS 17.0, *) {
            hasAccess = authorizationStatus == .fullAccess
        } else {
            hasAccess = authorizationStatus == .authorized
        }

        guard isCalendarSyncEnabled,
              hasAccess,
              let calendar = selectedCalendar else {
            print("📅 Sync failed - Enabled: \(isCalendarSyncEnabled), Auth: \(authorizationStatus), Calendar: \(selectedCalendar?.title ?? "none")")
            return false
        }
        
        // Check if task has any date information
        guard task.startDate != nil || task.dueDate != nil || task.endDate != nil else {
            print("📅 Sync failed - Task '\(task.title)' has no dates")
            return false
        }

        print("📅 Syncing task '\(task.title)' with due date: \(task.dueDate?.description ?? "none")")
        
        // Check if event already exists
        if let existingEvent = findExistingEvent(for: task) {
            return await updateCalendarEvent(existingEvent, with: task)
        } else {
            return await createCalendarEvent(for: task, in: calendar)
        }
    }
    
    func removeTaskFromCalendar(_ task: VikunjaTask) async -> Bool {
        let hasAccess: Bool
        if #available(iOS 17.0, *) {
            hasAccess = authorizationStatus == .fullAccess
        } else {
            hasAccess = authorizationStatus == .authorized
        }
        guard hasAccess else { return false }
        
        if let existingEvent = findExistingEvent(for: task) {
            do {
                try eventStore.remove(existingEvent, span: .thisEvent)
                syncedEventIdentifiers.remove(existingEvent.eventIdentifier)
                syncSuccessMessage = "Task '\(task.title)' removed from calendar"
                return true
            } catch {
                syncErrors.append("Failed to remove task '\(task.title)' from calendar: \(error.localizedDescription)")
                return false
            }
        }
        return true
    }
    
    // MARK: - Private Methods
    
    private func createCalendarEvent(for task: VikunjaTask, in calendar: EKCalendar) async -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = task.title
        event.notes = task.description
        
        // Set event dates based on task dates
        let (startDate, endDate) = calculateEventDates(for: task)
        event.startDate = startDate
        event.endDate = endDate
        
        // Add task ID to URL for identification
        event.url = URL(string: "kuna://task/\(task.id)")
        
        // Note: EKEvent doesn't have a priority property in EventKit
        // Priority could be represented through calendar color or in the notes field
        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            event.notes = (event.notes ?? "") + priorityNote
        }
        
        // Add reminders
        if let reminders = task.reminders, !reminders.isEmpty {
            event.alarms = reminders.compactMap { reminder in
                EKAlarm(absoluteDate: reminder.reminder)
            }
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            syncedEventIdentifiers.insert(event.eventIdentifier)
            syncSuccessMessage = "Task '\(task.title)' synced to calendar"
            return true
        } catch {
            syncErrors.append("Failed to create calendar event for task '\(task.title)': \(error.localizedDescription)")
            return false
        }
    }
    
    private func updateCalendarEvent(_ event: EKEvent, with task: VikunjaTask) async -> Bool {
        event.title = task.title
        event.notes = task.description
        
        let (startDate, endDate) = calculateEventDates(for: task)
        event.startDate = startDate
        event.endDate = endDate
        
        // Note: EKEvent doesn't have a priority property in EventKit
        // Priority is included in the notes field
        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            event.notes = (event.notes ?? "") + priorityNote
        }
        
        // Update reminders
        if let reminders = task.reminders, !reminders.isEmpty {
            event.alarms = reminders.compactMap { reminder in
                EKAlarm(absoluteDate: reminder.reminder)
            }
        } else {
            event.alarms = []
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            syncSuccessMessage = "Task '\(task.title)' updated in calendar"
            return true
        } catch {
            syncErrors.append("Failed to update calendar event for task '\(task.title)': \(error.localizedDescription)")
            return false
        }
    }
    
    private func findExistingEvent(for task: VikunjaTask) -> EKEvent? {
        guard let calendar = selectedCalendar else { return nil }
        
        // Search for events with our custom URL scheme
        let predicate = eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-365 * 24 * 60 * 60), // 1 year ago
            end: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year from now
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        return events.first { event in
            event.url?.absoluteString == "kuna://task/\(task.id)"
        }
    }
    
    private func calculateEventDates(for task: VikunjaTask) -> (start: Date, end: Date) {
        let now = Date()
        
        // Priority order: startDate -> dueDate -> endDate
        if let startDate = task.startDate {
            let endDate = task.endDate ?? task.dueDate ?? startDate.addingTimeInterval(3600) // 1 hour default
            return (startDate, endDate)
        } else if let dueDate = task.dueDate {
            let startDate = task.startDate ?? dueDate.addingTimeInterval(-3600) // 1 hour before due
            return (startDate, dueDate)
        } else if let endDate = task.endDate {
            let startDate = endDate.addingTimeInterval(-3600) // 1 hour before end
            return (startDate, endDate)
        } else {
            // Fallback to current time + 1 hour
            return (now, now.addingTimeInterval(3600))
        }
    }
    

    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        isCalendarSyncEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
        
        if let calendarIdentifier = UserDefaults.standard.string(forKey: "selectedCalendarIdentifier") {
            selectedCalendar = eventStore.calendar(withIdentifier: calendarIdentifier)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isCalendarSyncEnabled, forKey: "calendarSyncEnabled")
        UserDefaults.standard.set(selectedCalendar?.calendarIdentifier, forKey: "selectedCalendarIdentifier")
    }
    
    func setCalendarSyncEnabled(_ enabled: Bool) {
        isCalendarSyncEnabled = enabled
        saveSettings()
    }
    
    // MARK: - Bidirectional Sync

    func syncCalendarChangesToTasks(api: VikunjaAPI) async -> [VikunjaTask] {
        let hasAccess: Bool
        if #available(iOS 17.0, *) {
            hasAccess = authorizationStatus == .fullAccess
        } else {
            hasAccess = authorizationStatus == .authorized
        }

        guard isCalendarSyncEnabled,
              hasAccess,
              let calendar = selectedCalendar else {
            return []
        }

        var updatedTasks: [VikunjaTask] = []

        // Get events from the last 30 days to 30 days in the future
        let startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let endDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        let kunaEvents = events.filter { event in
            event.url?.absoluteString.hasPrefix("kuna://task/") == true
        }

        for event in kunaEvents {
            if let taskIdString = event.url?.absoluteString.replacingOccurrences(of: "kuna://task/", with: ""),
               let taskId = Int(taskIdString) {

                do {
                    // Fetch the current task from the API
                    let currentTask = try await api.getTask(taskId: taskId)

                    // Check if the event has been modified since last sync
                    if let updatedTask = updateTaskFromEvent(currentTask, event: event) {
                        // Update the task via API
                        let savedTask = try await api.updateTask(updatedTask)
                        updatedTasks.append(savedTask)
                    }
                } catch {
                    syncErrors.append("Failed to sync calendar changes for task \(taskId): \(error.localizedDescription)")
                }
            }
        }

        return updatedTasks
    }

    private func updateTaskFromEvent(_ task: VikunjaTask, event: EKEvent) -> VikunjaTask? {
        var updatedTask = task
        var hasChanges = false

        // Update title if different
        if task.title != event.title {
            updatedTask.title = event.title
            hasChanges = true
        }

        // Update description if different
        let eventNotes = event.notes ?? ""
        let taskDescription = task.description ?? ""
        if taskDescription != eventNotes {
            updatedTask.description = eventNotes.isEmpty ? nil : eventNotes
            hasChanges = true
        }

        // Update dates if different
        if task.startDate != event.startDate {
            updatedTask.startDate = event.startDate
            hasChanges = true
        }

        if task.endDate != event.endDate {
            updatedTask.endDate = event.endDate
            hasChanges = true
        }

        // For due date, use end date if it's different from start date
        if event.startDate != event.endDate {
            if task.dueDate != event.endDate {
                updatedTask.dueDate = event.endDate
                hasChanges = true
            }
        }

        // Update reminders if different
        let eventAlarms = event.alarms ?? []
        let eventReminderDates = eventAlarms.compactMap { alarm in
            alarm.absoluteDate
        }

        let taskReminderDates = task.reminders?.map { $0.reminder } ?? []

        if Set(eventReminderDates) != Set(taskReminderDates) {
            updatedTask.reminders = eventReminderDates.map { Reminder(reminder: $0) }
            hasChanges = true
        }

        return hasChanges ? updatedTask : nil
    }

    // MARK: - Conflict Resolution

    enum SyncConflictResolution {
        case preferTask
        case preferCalendar
        case manual
    }

    func resolveSyncConflict(
        task: VikunjaTask,
        event: EKEvent,
        resolution: SyncConflictResolution
    ) async -> Bool {
        switch resolution {
        case .preferTask:
            return await updateCalendarEvent(event, with: task)
        case .preferCalendar:
            if updateTaskFromEvent(task, event: event) != nil {
                // This would need to be handled by the caller since we don't have API access here
                return true
            }
            return false
        case .manual:
            // Manual resolution would be handled by the UI
            return false
        }
    }

    // MARK: - Error Management

    func clearErrors() {
        syncErrors.removeAll()
    }

    func clearSuccessMessage() {
        syncSuccessMessage = nil
    }

    // MARK: - New Engine Methods

    func setAPI(_ api: VikunjaAPI) {
        syncEngine.setAPI(api)
    }

    func enableNewSync() async throws {
        try await syncEngine.enable()
        isCalendarSyncEnabled = syncEngine.isEnabled
    }

    func disableNewSync() {
        syncEngine.disable()
        isCalendarSyncEnabled = syncEngine.isEnabled
    }

    func performFullSync() async {
        await syncEngine.syncNow(mode: .pullOnly)
    }

    func performTwoWaySync() async {
        await syncEngine.syncNow(mode: .twoWay)
    }

    func setReadWriteEnabled(_ enabled: Bool) {
        syncEngine.setReadWriteEnabled(enabled)
    }

    func setEnabledLists(_ listIDs: [String]) {
        syncEngine.setEnabledLists(listIDs)
    }
}
