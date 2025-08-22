import Foundation
import EventKit

// MARK: - CalendarSyncEngineType Protocol

protocol CalendarSyncEngineType: AnyObject {
    func onboardingBegin() async
    func onboardingComplete(mode: CalendarSyncMode, selectedProjectIDs: Set<String>) async throws -> CalendarSyncPrefs
    func enableSync() async throws
    func disableSync(disposition: DisableDisposition) async throws
    func resyncNow() async
    func handleEventStoreChanged() async
}

@MainActor
final class CalendarSyncEngine: ObservableObject, CalendarSyncEngineType {

    // MARK: - Dependencies

    private let eventKitClient: EventKitClient
    private var api: VikunjaAPI?

    // MARK: - State (UI)
    @Published var isEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []

    // MARK: - Internal state
    private var currentPrefs: CalendarSyncPrefs
    private var resolvedCalendars: [String: EKCalendar] = [:]

    // Counters for sync summary
    private var createdCount = 0
    private var updatedCount = 0
    private var removedCount = 0

    // MARK: - Initialization

    init(eventKitClient: EventKitClient = EventKitClientLive()) {
        self.eventKitClient = eventKitClient
        // Initialize with default prefs to avoid circular dependency
        self.currentPrefs = CalendarSyncPrefs()
        self.isEnabled = false
        self.lastSyncDate = UserDefaults.standard.object(forKey: "calendarSync.lastSyncDate") as? Date

        setupEventStoreNotifications()
        
        // Load actual preferences after initialization
        loadCurrentPreferences()
    }

    // MARK: - Configuration

    func setAPI(_ api: VikunjaAPI) {
        self.api = api
    }
    
    private func loadCurrentPreferences() {
        // Safely load preferences without causing circular dependency
        Task { @MainActor in
            // Small delay to ensure AppSettings is fully initialized
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if let data = UserDefaults.standard.data(forKey: "calendarSync.prefs"),
               let prefs = try? JSONDecoder().decode(CalendarSyncPrefs.self, from: data) {
                self.currentPrefs = prefs
                self.isEnabled = prefs.isEnabled
            }
        }
    }

    // MARK: - CalendarSyncEngineType Implementation

    func onboardingBegin() async {
        // Reset any existing state
        resolvedCalendars.removeAll()
        syncErrors.removeAll()
    }

    func onboardingComplete(mode: CalendarSyncMode, selectedProjectIDs: Set<String>) async throws -> CalendarSyncPrefs {
        // Request calendar access
        try await eventKitClient.requestAccess()

        // Get writable source
        guard let source = eventKitClient.writableSource() else {
            throw EventKitError.calendarCreationFailed
        }

        // Store old state for mode switching
        let oldMode = currentPrefs.mode
        let oldCalendars = resolvedCalendars

        // Create new preferences
        var newPrefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: mode,
            selectedProjectIDs: selectedProjectIDs
        )

        // Resolve/create calendars based on mode
        try await resolveCalendars(for: newPrefs, source: source)

        // Update preferences with calendar references
        updatePreferencesWithResolvedCalendars(&newPrefs)

        // Handle mode switching if this is a reconfiguration
        if currentPrefs.isEnabled && oldMode != mode {
            try await switchMode(from: oldMode, to: mode, oldCalendars: oldCalendars, newCalendars: resolvedCalendars)
        }

        // Save preferences
        currentPrefs = newPrefs
        isEnabled = true
        
        // Update AppSettings with the resolved preferences
        await updateAppSettings(with: newPrefs)

        // Perform initial sync
        await performInitialSync()
        
        // Return the resolved preferences for the caller to update AppSettings
        return newPrefs
    }

    func enableSync() async throws {
        guard !isEnabled else { return }

        try await eventKitClient.requestAccess()
        
        guard currentPrefs.isValid else {
            throw EventKitError.calendarNotFound
        }

        isEnabled = true
        await performInitialSync()
    }

    func disableSync(disposition: DisableDisposition) async throws {
        Log.app.info("📅 Disabling sync with disposition: \(disposition)")
        
        // Ensure we have the current calendars loaded before performing cleanup
        if currentPrefs.isEnabled && !self.resolvedCalendars.isEmpty {
            Log.app.info("📅 Using existing resolved calendars (\(self.resolvedCalendars.count))")
        } else if currentPrefs.isValid {
            Log.app.info("📅 Refreshing resolved calendars before cleanup")
            try await refreshResolvedCalendars()
            Log.app.info("📅 Refreshed calendars, now have \(self.resolvedCalendars.count)")
        } else {
            Log.app.warning("📅 No valid preferences found, proceeding with cleanup anyway")
        }
        
        switch disposition {
        case .keepEverything:
            Log.app.info("📅 Keeping everything - just disabling sync")
            isEnabled = false
            
        case .removeKunaEvents:
            Log.app.info("📅 Removing Kuna events, keeping calendars")
            try await removeKunaEvents()
            isEnabled = false
            
        case .archiveCalendars:
            Log.app.info("📅 Archiving calendars")
            try await archiveCalendars()
            isEnabled = false
            
        case .deleteEverything:
            Log.app.info("📅 Deleting everything - events and calendars")
            try await deleteKunaCalendars()
            isEnabled = false
        }

        // Clear resolved calendars and reset prefs
        Log.app.info("📅 Clearing resolved calendars and resetting preferences")
        resolvedCalendars.removeAll()
        currentPrefs = CalendarSyncPrefs()
        
        Log.app.info("📅 Calendar sync disabled successfully")
    }

    func resyncNow() async {
        await performSync()
    }

    func handleEventStoreChanged() async {
        guard isEnabled else { return }
        
        // Debounce event store changes
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await performSync()
    }

    // MARK: - Sync Implementation

    private func performInitialSync() async {
        await performSync()
    }

    private func performSync() async {
        guard isEnabled, !isSyncing, let api = api else { return }

        isSyncing = true
        createdCount = 0
        updatedCount = 0
        removedCount = 0
        defer { isSyncing = false }

        do {
            // Refresh resolved calendars from current preferences
            try await refreshResolvedCalendars()

            // Fetch tasks from selected projects
            let tasks = try await fetchFilteredTasks(api: api)

            // Build desired event set
            let desiredEvents = buildDesiredEvents(from: tasks)

            // Fetch existing Kuna events
            let existingEvents = fetchExistingKunaEvents()

            // Perform diff and sync
            try await performDiffSync(desired: desiredEvents, existing: existingEvents)

            // Update last sync date
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "calendarSync.lastSyncDate")

            Log.app.debug("📅 Sync completed — created: \(self.createdCount) • updated: \(self.updatedCount) • removed: \(self.removedCount)")

        } catch {
            syncErrors.append("Sync failed: \(error.localizedDescription)")
            Log.app.error("📅 Sync error: \(error)")
        }
    }

    // MARK: - Calendar Resolution

    private func resolveCalendars(for prefs: CalendarSyncPrefs, source: EKSource) async throws {
        switch prefs.mode {
        case .single:
            let calendar = try eventKitClient.ensureCalendar(named: "Kuna", in: source)
            resolvedCalendars["single"] = calendar

        case .perProject:
            // Get project names from API or use project IDs
            for projectID in prefs.selectedProjectIDs {
                let projectName = await getProjectName(for: projectID) ?? "Project \(projectID)"
                let calendarName = "Kuna – \(projectName)"
                let calendar = try eventKitClient.ensureCalendar(named: calendarName, in: source)
                resolvedCalendars[projectID] = calendar
            }
        }
    }

    private func refreshResolvedCalendars() async throws {
        resolvedCalendars.removeAll()

        switch currentPrefs.mode {
        case .single:
            if let calRef = currentPrefs.singleCalendar {
                let calendars = eventKitClient.calendars(for: [calRef.identifier])
                if let calendar = calendars.first {
                    resolvedCalendars["single"] = calendar
                } else {
                    // Calendar no longer exists, try to recreate
                    if let source = eventKitClient.writableSource() {
                        let calendar = try eventKitClient.ensureCalendar(named: calRef.name, in: source)
                        resolvedCalendars["single"] = calendar
                    }
                }
            }

        case .perProject:
            for (projectID, calRef) in currentPrefs.projectCalendars {
                let calendars = eventKitClient.calendars(for: [calRef.identifier])
                if let calendar = calendars.first {
                    resolvedCalendars[projectID] = calendar
                } else {
                    // Calendar no longer exists, try to recreate
                    if let source = eventKitClient.writableSource() {
                        let calendar = try eventKitClient.ensureCalendar(named: calRef.name, in: source)
                        resolvedCalendars[projectID] = calendar
                    }
                }
            }
        }
    }

    private func updatePreferencesWithResolvedCalendars(_ prefs: inout CalendarSyncPrefs) {
        switch prefs.mode {
        case .single:
            if let calendar = resolvedCalendars["single"] {
                prefs.singleCalendar = KunaCalendarRef(
                    name: calendar.title,
                    identifier: calendar.calendarIdentifier
                )
            }

        case .perProject:
            prefs.projectCalendars.removeAll()
            for (projectID, calendar) in resolvedCalendars {
                prefs.projectCalendars[projectID] = KunaCalendarRef(
                    name: calendar.title,
                    identifier: calendar.calendarIdentifier
                )
            }
        }
    }

    // MARK: - Task and Event Operations

    private func fetchFilteredTasks(api: VikunjaAPI) async throws -> [VikunjaTask] {
        // Fetch tasks from selected projects
        var allTasks: [VikunjaTask] = []
        
        for projectIDString in currentPrefs.selectedProjectIDs {
            guard let projectID = Int(projectIDString) else { continue }
            let tasks = try await api.fetchTasks(projectId: projectID)
            allTasks.append(contentsOf: tasks)
        }
        
        return allTasks
    }

    private func buildDesiredEvents(from tasks: [VikunjaTask]) -> [String: DesiredEvent] {
        var desired: [String: DesiredEvent] = [:]

        for task in tasks {
            guard let calendarKey = calendarKey(for: task) else { continue }
            guard let calendar = resolvedCalendars[calendarKey] else { continue }

            // Map task to event fields
            if let desiredEvent = mapTaskToDesiredEvent(task: task, calendar: calendar) {
                let eventKey = "task_\(task.id)"
                desired[eventKey] = desiredEvent
            }
        }

        return desired
    }

    private func fetchExistingKunaEvents() -> [EKEvent] {
        let calendars = Array(resolvedCalendars.values)
        guard !calendars.isEmpty else { return [] }

        // Wide time window for existing events
        let start = Date().addingTimeInterval(-365 * 24 * 60 * 60) // 1 year back
        let end = Date().addingTimeInterval(2 * 365 * 24 * 60 * 60) // 2 years forward

        let allEvents = eventKitClient.events(in: calendars, start: start, end: end)
        return allEvents.filter { $0.isKunaEvent }
    }

    private func performDiffSync(desired: [String: DesiredEvent], existing: [EKEvent]) async throws {
        // Create map of existing events by task ID
        var existingByTaskID: [Int: EKEvent] = [:]
        for event in existing {
            if let taskInfo = event.extractTaskInfo() {
                existingByTaskID[taskInfo.taskID] = event
            }
        }

        // Process desired events
        for (_, desiredEvent) in desired {
            if let existingEvent = existingByTaskID[desiredEvent.taskID] {
                // Update existing event
                if shouldUpdateEvent(existing: existingEvent, desired: desiredEvent) {
                    updateEvent(existing: existingEvent, with: desiredEvent)
                    try eventKitClient.save(event: existingEvent)
                    updatedCount += 1
                }
                existingByTaskID.removeValue(forKey: desiredEvent.taskID)
            } else {
                // Create new event
                let newEvent = createEvent(from: desiredEvent)
                try eventKitClient.save(event: newEvent)
                createdCount += 1
            }
        }

        // Remove stale events
        for (_, staleEvent) in existingByTaskID {
            try eventKitClient.remove(event: staleEvent)
            removedCount += 1
        }

        // Commit all changes
        try eventKitClient.commit()
    }

    // MARK: - Event Mapping

    private func calendarKey(for task: VikunjaTask) -> String? {
        switch currentPrefs.mode {
        case .single:
            return "single"
        case .perProject:
            return task.projectId.map(String.init)
        }
    }

    private func mapTaskToDesiredEvent(task: VikunjaTask, calendar: EKCalendar) -> DesiredEvent? {
        // Determine dates based on task properties
        let (startDate, endDate, isAllDay) = determineDatesForTask(task)
        
        guard let start = startDate, let end = endDate else {
            return nil // Skip tasks without dates
        }

        return DesiredEvent(
            taskID: task.id,
            calendar: calendar,
            title: task.title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            notes: buildEventNotes(for: task),
            url: URL(string: "kuna://task/\(task.id)?project=\(task.projectId ?? 0)")
        )
    }

    private func determineDatesForTask(_ task: VikunjaTask) -> (start: Date?, end: Date?, isAllDay: Bool) {
        // Implementation based on spec mapping rules
        if let startDate = task.startDate, let dueDate = task.dueDate {
            return (startDate, dueDate, false)
        } else if let dueDate = task.dueDate {
            if task.done {
                // For done tasks, create all-day event on due date
                return (dueDate, dueDate, true)
            } else {
                // Default 1-hour event ending at due date
                let startDate = dueDate.addingTimeInterval(-3600) // 1 hour before
                return (startDate, dueDate, false)
            }
        } else if let startDate = task.startDate {
            let endDate = startDate.addingTimeInterval(3600) // 1 hour duration
            return (startDate, endDate, false)
        }
        
        return (nil, nil, false)
    }

    private func buildEventNotes(for task: VikunjaTask) -> String {
        var notes = "KUNA_EVENT: task=\(task.id) project=\(task.projectId ?? 0)"
        
        if let description = task.description, !description.isEmpty {
            notes += "\n\n\(description)"
        }
        
        return notes
    }

    // MARK: - Event Operations

    private func shouldUpdateEvent(existing: EKEvent, desired: DesiredEvent) -> Bool {
        return existing.title != desired.title ||
               existing.startDate != desired.startDate ||
               existing.endDate != desired.endDate ||
               existing.isAllDay != desired.isAllDay ||
               existing.notes != desired.notes
    }

    private func updateEvent(existing: EKEvent, with desired: DesiredEvent) {
        existing.title = desired.title
        existing.startDate = desired.startDate
        existing.endDate = desired.endDate
        existing.isAllDay = desired.isAllDay
        existing.notes = desired.notes
        existing.url = desired.url
    }

    private func createEvent(from desired: DesiredEvent) -> EKEvent {
        let event = EKEvent(eventStore: eventKitClient.store)
        event.calendar = desired.calendar
        event.title = desired.title
        event.startDate = desired.startDate
        event.endDate = desired.endDate
        event.isAllDay = desired.isAllDay
        event.notes = desired.notes
        event.url = desired.url
        event.setKunaTaskInfo(taskID: desired.taskID, projectID: desired.taskID) // Simplified for now
        return event
    }

    // MARK: - Mode Switching Logic

    private func switchMode(from oldMode: CalendarSyncMode, to newMode: CalendarSyncMode, 
                           oldCalendars: [String: EKCalendar], newCalendars: [String: EKCalendar]) async throws {
        let existingEvents = fetchExistingKunaEvents()
        
        switch (oldMode, newMode) {
        case (.single, .perProject):
            // Move events from single calendar to per-project calendars
            try await moveEventsFromSingleToPerProject(events: existingEvents, newCalendars: newCalendars)
            
        case (.perProject, .single):
            // Move events from per-project calendars to single calendar
            try await moveEventsFromPerProjectToSingle(events: existingEvents, singleCalendar: newCalendars["single"]!)
            
        case (.single, .single), (.perProject, .perProject):
            // Same mode, but potentially different calendars or projects
            // Re-sync with new configuration
            break
        }
    }
    
    private func moveEventsFromSingleToPerProject(events: [EKEvent], newCalendars: [String: EKCalendar]) async throws {
        for event in events {
            guard let taskInfo = event.extractTaskInfo() else { continue }
            
            // Determine which calendar this event should go to
            let projectKey = String(taskInfo.projectID)
            guard let targetCalendar = newCalendars[projectKey] else { continue }
            
            // Create a copy in the target calendar
            let newEvent = EKEvent(eventStore: eventKitClient.store)
            newEvent.calendar = targetCalendar
            newEvent.title = event.title
            newEvent.startDate = event.startDate
            newEvent.endDate = event.endDate
            newEvent.isAllDay = event.isAllDay
            newEvent.notes = event.notes
            newEvent.url = event.url
            
            try eventKitClient.save(event: newEvent)
            
            // Remove the original event
            try eventKitClient.remove(event: event)
        }
        
        try eventKitClient.commit()
    }
    
    private func moveEventsFromPerProjectToSingle(events: [EKEvent], singleCalendar: EKCalendar) async throws {
        for event in events {
            // Create a copy in the single calendar
            let newEvent = EKEvent(eventStore: eventKitClient.store)
            newEvent.calendar = singleCalendar
            newEvent.title = event.title
            newEvent.startDate = event.startDate
            newEvent.endDate = event.endDate
            newEvent.isAllDay = event.isAllDay
            newEvent.notes = event.notes
            newEvent.url = event.url
            
            try eventKitClient.save(event: newEvent)
            
            // Remove the original event
            try eventKitClient.remove(event: event)
        }
        
        try eventKitClient.commit()
    }

    // MARK: - Cleanup Operations

    private func removeKunaEvents() async throws {
        let existingEvents = fetchExistingKunaEvents()
        
        guard !existingEvents.isEmpty else {
            Log.app.info("📅 No Kuna events found to remove")
            return
        }
        
        Log.app.info("📅 Removing \(existingEvents.count) Kuna event(s)")
        
        for event in existingEvents {
            Log.app.debug("📅 Removing event: '\(event.title ?? "Untitled")'")
            try eventKitClient.remove(event: event)
        }
        
        try eventKitClient.commit()
        Log.app.info("📅 Event removal committed")
    }

    private func archiveCalendars() async throws {
        guard !resolvedCalendars.isEmpty else {
            Log.app.warning("📅 No resolved calendars found to archive")
            return
        }
        
        Log.app.info("📅 Archiving \(self.resolvedCalendars.count) calendar(s)")
        
        for (_, calendar) in self.resolvedCalendars {
            let originalTitle = calendar.title
            if !originalTitle.hasSuffix(" (Archive)") {
                calendar.title = "\(originalTitle) (Archive)"
                Log.app.info("📅 Renamed calendar '\(originalTitle)' to '\(calendar.title)'")
            } else {
                Log.app.info("📅 Calendar '\(originalTitle)' already archived")
            }
        }
        
        try eventKitClient.commit()
        Log.app.info("📅 Calendar archiving committed")
    }
    
    private func deleteKunaCalendars() async throws {
        guard !self.resolvedCalendars.isEmpty else {
            Log.app.warning("📅 No resolved calendars found to delete")
            return
        }
        
        Log.app.info("📅 Deleting \(self.resolvedCalendars.count) Kuna calendar(s)")
        
        for (_, calendar) in self.resolvedCalendars {
            Log.app.info("📅 Deleting calendar: '\(calendar.title)'")
            try eventKitClient.remove(calendar: calendar)
        }
        
        try eventKitClient.commit()
        Log.app.info("📅 Calendar deletion committed")
    }

    // MARK: - Helper Methods
    
    private func updateAppSettings(with prefs: CalendarSyncPrefs) async {
        // Update UserDefaults directly to persist the preferences
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "calendarSync.prefs")
            
            // Also update the old calendarSyncEnabled setting for backwards compatibility
            UserDefaults.standard.set(prefs.isEnabled, forKey: "calendarSyncEnabled")
        }
    }

    private func getProjectName(for projectID: String) async -> String? {
        guard let api = api, let projectIDInt = Int(projectID) else {
            return nil
        }
        
        do {
            let projects = try await api.fetchProjects()
            let project = projects.first { $0.id == projectIDInt }
            return project?.title
        } catch {
            Log.app.error("📅 Failed to fetch project name for \(projectID): \(error)")
            return nil
        }
    }

    private func setupEventStoreNotifications() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventKitClient.store,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.handleEventStoreChanged() }
        }
    }
}

// MARK: - Supporting Types

private struct DesiredEvent {
    let taskID: Int
    let calendar: EKCalendar
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let notes: String
    let url: URL?
}
