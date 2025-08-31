// Services/CalendarSyncService.swift
import Foundation
import EventKit
import SwiftUI

@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    // MARK: - New Engine Integration
    private let syncEngine = CalendarSyncEngine()

    // MARK: - Legacy / Bridging Properties (kept for compatibility)
    let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isCalendarSyncEnabled: Bool = false
    @Published var selectedCalendar: EKCalendar?
    @Published var syncErrors: [String] = []
    @Published var syncSuccessMessage: String?

    private var syncedEventIdentifiers: Set<String> = []

    private init() {
        updateAuthorizationStatus()
        loadSettings()
        setupEngineBinding()
    }

    private func setupEngineBinding() {
        // Keep manager screens in sync with new engine
        syncEngine.$isEnabled.assign(to: &$isCalendarSyncEnabled)
        syncEngine.$syncErrors.assign(to: &$syncErrors)
        
        // Update enabled status based on preferences
        isCalendarSyncEnabled = AppSettings.shared.calendarSyncPrefs.isEnabled
    }
    
    // MARK: - Engine Delegation
    
    func setCalendarSyncEnabled(_ enabled: Bool) {
        // This method is called by AppSettings when the toggle changes
        // The actual logic is now handled by the new CalendarSyncEngine
        if enabled != isCalendarSyncEnabled {
            isCalendarSyncEnabled = enabled
        }
    }

    // MARK: - Authorization

    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestCalendarAccess() async -> Bool {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        switch currentStatus {
        case .fullAccess, .authorized:
            await MainActor.run { updateAuthorizationStatus() }
            return true

        case .notDetermined:
            do {
                if #available(iOS 17.0, *) {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    await MainActor.run { updateAuthorizationStatus() }
                    return granted
                } else {
                    return await withCheckedContinuation { continuation in
                        eventStore.requestAccess(to: .event) { granted, _ in
                            Task { @MainActor in self.updateAuthorizationStatus() }
                            continuation.resume(returning: granted)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    syncErrors.append("Failed to request calendar access: \(error.localizedDescription)")
                    updateAuthorizationStatus()
                }
                return false
            }

        case .denied, .restricted, .writeOnly:
            await MainActor.run {
                syncErrors.append("Calendar access not sufficient. Enable in Settings > Privacy & Security > Calendars.")
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

    // MARK: - Calendar List (legacy picker)

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
    
    // MARK: - Project Filtering
    
    /// Check if a task should be synced based on project filter settings
    private func shouldSyncTaskBasedOnProject(_ task: VikunjaTask) -> Bool {
        let settings = AppSettings.shared
        
        // If syncing all projects, always sync
        if settings.syncAllProjects {
            return true
        }
        
        // Check if the task's project is in the selected set
        guard let projectId = task.projectId else { return false }
        return settings.selectedProjectsForSync.contains(String(projectId))
    }
    
    // MARK: - Default Calendar Management
    
    /// Creates or finds the default "Kuna Tasks" calendar
    @MainActor
    func getOrCreateDefaultCalendar() -> EKCalendar? {
        // First check if we have calendar access
        let hasAccess: Bool = {
            if #available(iOS 17.0, *) {
                return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
            } else {
                return authorizationStatus == .authorized
            }
        }()
        
        guard hasAccess else { return nil }
        
        // Look for existing "Kuna Tasks" calendar
        let existingCalendars = eventStore.calendars(for: .event)
        if let kunaCalendar = existingCalendars.first(where: { $0.title == "Kuna Tasks" }) {
            return kunaCalendar
        }
        
        // Create new "Kuna Tasks" calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "Kuna Tasks"
        
        // Set a nice color for the calendar (purple/indigo)
        newCalendar.cgColor = UIColor.systemIndigo.cgColor
        
        // Find the default calendar source (usually iCloud or Local)
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            newCalendar.source = iCloudSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else {
            // Fallback to first available source
            guard let firstSource = eventStore.sources.first else { return nil }
            newCalendar.source = firstSource
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            syncErrors.append("Failed to create Kuna Tasks calendar: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Legacy Sync ops (used by CalendarSyncManager)

    /// One-off: push a single task into the currently selected calendar.
    func syncTaskToCalendar(_ task: VikunjaTask) async -> Bool {
        let hasAccess: Bool = {
            if #available(iOS 17.0, *) {
                return authorizationStatus == .fullAccess
            } else {
                return authorizationStatus == .authorized 
            }
        }()
        guard isCalendarSyncEnabled, hasAccess, let calendar = selectedCalendar else {
            return false
        }

        // Only sync tasks that actually have dates
        guard task.startDate != nil || task.dueDate != nil || task.endDate != nil else {
            return false
        }
        
        // Check project filter settings
        if !shouldSyncTaskBasedOnProject(task) {
            return false
        }

        if let existingEvent = findExistingEvent(for: task, in: calendar) {
            return await updateCalendarEvent(existingEvent, with: task)
        } else {
            return await createCalendarEvent(for: task, in: calendar)
        }
    }

    func removeTaskFromCalendar(_ task: VikunjaTask) async -> Bool {
        let hasAccess: Bool = {
            if #available(iOS 17.0, *) {
                return authorizationStatus == .fullAccess
            } else {
                return authorizationStatus == .authorized
            }
        }()
        guard hasAccess, let cal = selectedCalendar else { return false }

        if let existingEvent = findExistingEvent(for: task, in: cal) {
            do {
                try eventStore.remove(existingEvent, span: .thisEvent)
                syncedEventIdentifiers.remove(existingEvent.eventIdentifier)
                syncSuccessMessage = "Removed ‘\(task.title)’ from calendar"
                return true
            } catch {
                syncErrors.append("Remove failed: \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    // Exposed so conflict resolver can write the event
    func updateCalendarEvent(_ event: EKEvent, with task: VikunjaTask) async -> Bool {
        event.title = task.title
        event.notes = task.description

        let (startDate, endDate) = calculateEventDates(for: task)
        
        event.startDate = startDate
        event.endDate = endDate

        // ✅ Keep a stable identifier for reliable lookups on subsequent edits
        event.url = URL(string: "kuna://task/\(task.id)")

        // Handle priority note without duplicating it
        var baseNotes = (event.notes ?? "")
        baseNotes = baseNotes.replacingOccurrences(
            of: #"\n\[Priority:.*\]$"#,
            with: "",
            options: .regularExpression
        )

        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            event.notes = baseNotes + priorityNote
        } else {
            event.notes = baseNotes
        }

        if let reminders = task.reminders, !reminders.isEmpty {
            event.alarms = reminders.map { EKAlarm(absoluteDate: $0.reminder) }
        } else {
            event.alarms = []
        }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            syncSuccessMessage = "Updated calendar event for '\(task.title)'"
            return true
        } catch {
            syncErrors.append("Update failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Build a patched task from a calendar event (used by preferCalendar resolution).
    func buildUpdatedTaskFromEvent(_ task: VikunjaTask, event: EKEvent) -> VikunjaTask? {
        var updatedTask = task
        var changed = false

        if task.title != event.title { updatedTask.title = event.title; changed = true }
        let eventNotes = event.notes ?? ""
        if (task.description ?? "") != eventNotes {
            updatedTask.description = eventNotes.isEmpty ? nil : eventNotes
            changed = true
        }
        if task.startDate != event.startDate { updatedTask.startDate = event.startDate; changed = true }
        if task.endDate != event.endDate { updatedTask.endDate = event.endDate; changed = true }
        if event.startDate != event.endDate {
            if task.dueDate != event.endDate { updatedTask.dueDate = event.endDate; changed = true }
        }
        let taskReminderDates = Set(task.reminders?.map { $0.reminder } ?? [])
        let eventReminderDates = Set(event.alarms?.compactMap { $0.absoluteDate } ?? [])
        if taskReminderDates != eventReminderDates {
            updatedTask.reminders = eventReminderDates.map { Reminder(reminder: $0) }
            changed = true
        }

        return changed ? updatedTask : nil
    }

    // For CalendarSyncManager conflict resolver
    enum SyncConflictResolution {
        case preferTask
        case preferCalendar
        case preferNewest
        case manual
    }

    // Used by CalendarSyncManager to scan EK → API
    func syncCalendarChangesToTasks(api: VikunjaAPI) async -> [VikunjaTask] {
        let hasAccess: Bool = {
            if #available(iOS 17.0, *) { 
                return authorizationStatus == .fullAccess
            } else {
                return authorizationStatus == .authorized
            }
        }()
        guard isCalendarSyncEnabled, hasAccess, let calendar = selectedCalendar else { return [] }

        var updated: [VikunjaTask] = []
        let start = Date().addingTimeInterval(-30*24*60*60)
        let end   = Date().addingTimeInterval( 30*24*60*60)
        let pred = eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let events = eventStore.events(matching: pred).filter { $0.url?.absoluteString.hasPrefix("kuna://task/") == true }

        for ev in events {
            if let taskIdStr = ev.url?.absoluteString.replacingOccurrences(of: "kuna://task/", with: ""),
               let taskId = Int(taskIdStr) {
                do {
                    let current = try await api.getTask(taskId: taskId)
                    if let patched = buildUpdatedTaskFromEvent(current, event: ev) {
                        let saved = try await api.updateTask(patched)
                        updated.append(saved)
                    }
                } catch {
                    syncErrors.append("Calendar→Task sync failed (\(taskId)): \(error.localizedDescription)")
                }
            }
        }
        return updated
    }

    // MARK: - Private helpers (legacy)

    private func createCalendarEvent(for task: VikunjaTask, in calendar: EKCalendar) async -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = task.title
        event.notes = task.description

        let (startDate, endDate) = calculateEventDates(for: task)
        event.startDate = startDate
        event.endDate = endDate
        event.url = URL(string: "kuna://task/\(task.id)")

        if task.priority != .unset {
            let priorityNote = "\n[Priority: \(task.priority.displayName)]"
            event.notes = (event.notes ?? "").replacingOccurrences(
                of: #"\n\[Priority:.*\]$"#,
                with: "",
                options: .regularExpression
            ) + priorityNote
        }

        if let reminders = task.reminders, !reminders.isEmpty {
            event.alarms = reminders.map { EKAlarm(absoluteDate: $0.reminder) }
        }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            syncedEventIdentifiers.insert(event.eventIdentifier)
            syncSuccessMessage = "Synced '\(task.title)' to calendar"
            return true
        } catch {
            syncErrors.append("Create failed: \(error.localizedDescription)")
            return false
        }
    }

    private func findExistingEvent(for task: VikunjaTask, in calendar: EKCalendar) -> EKEvent? {
        // Refresh sources; do not reset the store (which loses identifiers/cache)
        eventStore.refreshSourcesIfNecessary()
        
        let window = DateInterval(start: Date().addingTimeInterval(-365*24*60*60),
                                  end: Date().addingTimeInterval(365*24*60*60))
        let pred = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
        let events = eventStore.events(matching: pred)
        
        return events.first { event in
            guard let u = event.url?.absoluteString else { return false }
            // Accept both plain and querystring variants
            return u == "kuna://task/\(task.id)" || u.hasPrefix("kuna://task/\(task.id)?")
        }
    }

    private func calculateEventDates(for task: VikunjaTask) -> (start: Date, end: Date) {
        let now = Date()
        
        // Determine start date
        let startDate: Date
        if let taskStart = task.startDate {
            startDate = taskStart
        } else if let taskDue = task.dueDate {
            // If no start date, use due date minus 1 hour as start
            startDate = taskDue.addingTimeInterval(-3600)
        } else if let taskEnd = task.endDate {
            // If only end date exists, use end date minus 1 hour as start
            startDate = taskEnd.addingTimeInterval(-3600)
        } else {
            // No dates at all (shouldn't happen as we check before syncing)
            startDate = now
        }
        
        // Determine end date - prioritize endDate, then dueDate, then startDate + 1 hour
        let endDate: Date
        if let taskEnd = task.endDate {
            endDate = taskEnd
        } else if let taskDue = task.dueDate {
            endDate = taskDue
        } else {
            // Only start date exists, make it a 1-hour event
            endDate = startDate.addingTimeInterval(3600)
        }
        
        return (startDate, endDate)
    }

    // MARK: - Settings Persistence (legacy bridge)

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

    // MARK: - Cleanup

    /// Remove **all** Kuna-tagged events from any Kuna calendar(s); then try deleting empty Kuna calendars.
    func tidyUpAllKunaCalendars() async {
        let hasReadAccess: Bool = {
            if #available(iOS 17.0, *) {
                return authorizationStatus == .fullAccess
            } else {
                return authorizationStatus == .authorized
            }
        }()
        guard hasReadAccess else { return }

        let all = eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
        let kunaCals = all.filter { $0.title == SyncConst.calendarTitle || $0.title.hasPrefix("Kuna: ") }
        let target = kunaCals.isEmpty ? all : kunaCals

        let start = Date().addingTimeInterval(-10 * 365 * 24 * 60 * 60)
        let end   = Date().addingTimeInterval( 10 * 365 * 24 * 60 * 60)

        var removed = 0
        for cal in target {
            let pred = eventStore.predicateForEvents(withStart: start, end: end, calendars: [cal])
            let events = eventStore.events(matching: pred).filter { $0.url?.scheme == SyncConst.scheme }
            for ev in events {
                do {
                    try eventStore.remove(ev, span: .thisEvent); removed += 1
                } catch { 
                    syncErrors.append("Cleanup remove failed: \(error.localizedDescription)")
                }
            }
        }
        if removed > 0 {
            syncSuccessMessage = "Removed \(removed) calendar events created by Kuna"
        }

        // Try to remove empty Kuna calendars
        for cal in kunaCals {
            let pred = eventStore.predicateForEvents(withStart: start, end: end, calendars: [cal])
            let hasAny = eventStore.events(matching: pred).isEmpty == false
            guard !hasAny else { continue }
            do {
                try eventStore.removeCalendar(cal, commit: true)
            } catch {
                // some sources don't allow deletion; ignore
            }
        }
    }

    /// Remove a single project's calendar (if per-project mode) by its title.
    func tidyUpProjectCalendar(projectTitle: String) async {
        let name = "Kuna: \(projectTitle)"
        let cals = eventStore.calendars(for: .event).filter { $0.title == name }
        guard let cal = cals.first else { return }
        let start = Date().addingTimeInterval(-5 * 365 * 24 * 60 * 60)
        let end   = Date().addingTimeInterval( 5 * 365 * 24 * 60 * 60)
        let pred = eventStore.predicateForEvents(withStart: start, end: end, calendars: [cal])
        let events = eventStore.events(matching: pred).filter { $0.url?.scheme == SyncConst.scheme }
        for ev in events {
            do { try eventStore.remove(ev, span: .thisEvent) } catch { /* ignore */ }
        }
        do { try eventStore.removeCalendar(cal, commit: true) } catch { /* ignore */ }
    }

    // MARK: - New Engine Methods (passthroughs)

    func setAPI(_ api: VikunjaAPI) { syncEngine.setAPI(api) }

    func enableNewSync() async throws {
        try await syncEngine.enableSync()
        isCalendarSyncEnabled = syncEngine.isEnabled
    }

    func disableNewSync() async throws {
        try await syncEngine.disableSync(disposition: .keepEverything)
        isCalendarSyncEnabled = syncEngine.isEnabled
    }

    func performFullSync() async { await syncEngine.resyncNow() }

    func performTwoWaySync() async { await syncEngine.resyncNow() }
    
    func syncAfterTaskUpdate() async { await syncEngine.syncAfterTaskUpdate() }
}
