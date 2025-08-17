// Services/CalendarSync/CalendarSyncEngine.swift
import Foundation
import EventKit

@MainActor
final class CalendarSyncEngine: ObservableObject {

    // MARK: - Dependencies

    private let calendarManager = CalendarManager()
    private let persistence = SyncStatePersistence()
    private let debouncer = Debouncer()
    private var api: CalendarSyncAPI?

    // MARK: - State

    @Published var isEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []
    @Published var readWriteEnabled: Bool = false

    private var syncState: CalendarSyncState
    private var idMap: IdMap
    private var kunaCalendar: EKCalendar?

    // MARK: - Settings

    private var enabledListIDs: [String] = [] // Will be populated from settings

    // MARK: - Initialization

    init() {
        self.syncState = persistence.loadSyncState()
        self.idMap = persistence.loadIdMap()
        self.lastSyncDate = syncState.lastLocalScanAt

        // Load settings
        loadSettings()

        // Setup event store change notifications
        setupEventStoreNotifications()
    }

    // MARK: - Configuration

    func setAPI(_ api: CalendarSyncAPI) {
        self.api = api
    }

    // MARK: - Public Interface

    func enable() async throws {
        guard !isEnabled else { return }

        // Request calendar access
        let hasAccess = try await calendarManager.requestAccess()
        guard hasAccess else {
            throw CalendarError.accessDenied
        }

        // Ensure Kuna calendar exists
        kunaCalendar = try calendarManager.ensureKunaCalendar()

        isEnabled = true
        saveSettings()

        // Perform initial sync
        await performInitialSync()
    }

    func disable() {
        isEnabled = false
        kunaCalendar = nil
        saveSettings()
    }

    func syncNow(mode: SyncMode = .pullOnly) async {
        guard isEnabled, !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await performSync(mode: mode)
            lastSyncDate = Date()
        } catch {
            syncErrors.append("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Implementation

    private func performInitialSync() async {
        // Clear existing state for fresh start
        syncState = CalendarSyncState()
        idMap = IdMap()

        await syncNow(mode: .pullOnly)
    }

    private func performSync(mode: SyncMode) async throws {
        let calendar: EKCalendar
        if let existingCalendar = kunaCalendar {
            calendar = existingCalendar
        } else {
            let newCalendar = try calendarManager.ensureKunaCalendar()
            kunaCalendar = newCalendar
            calendar = newCalendar
        }

        let window = SyncConst.rollingWindow()

        // PULL: Server → Calendar
        try await performPull(calendar: calendar, window: window)

        // PUSH: Calendar → Server (if enabled)
        if mode == .twoWay && readWriteEnabled {
            try await performPush(calendar: calendar)
        }

        // Persist state
        persistence.saveSyncState(syncState)
        persistence.saveIdMap(idMap)
    }

    private func performPull(calendar: EKCalendar, window: DateInterval) async throws {
        guard let api = api else {
            throw CalendarSyncError.apiError("API not configured")
        }

        let tasks = try await api.fetchTasks(
            updatedSince: syncState.remoteCursorISO8601,
            listIDs: enabledListIDs,
            window: window
        )

        for task in tasks {
            try await upsertEvent(for: task, in: calendar, window: window)
            syncState.remoteCursorISO8601 = maxISO8601(
                syncState.remoteCursorISO8601,
                task.updatedAtISO8601
            )
        }

        print("📅 Pull sync completed for window: \(window), processed \(tasks.count) tasks")
    }

    private func performPush(calendar: EKCalendar) async throws {
        let pushWindow = SyncConst.pushWindow()
        let changedEvents = calendarManager.eventsChangedSince(
            syncState.lastLocalScanAt,
            in: calendar,
            within: pushWindow
        )

        var patches: [TaskPatch] = []
        for event in changedEvents {
            if let patch = TaskEventMapper.extractCalendarEdits(from: event) {
                patches.append(patch)
            }
        }

        for patch in patches {
            try await processPatch(patch, in: calendar, window: pushWindow)
        }

        syncState.lastLocalScanAt = Date()
        print("📅 Push sync completed, processed \(patches.count) changes")
    }

    // MARK: - Event Operations

    private func upsertEvent(for task: CalendarSyncTask, in calendar: EKCalendar, window: DateInterval) async throws {
        // Find existing event
        let existingEvent = calendarManager.findEvent(
            byTaskId: task.id,
            in: calendar,
            window: window,
            idMap: idMap
        )

        if task.deleted {
            // Task is completed/deleted - remove event if it exists
            if let event = existingEvent {
                try calendarManager.remove(event)
                idMap.removeMapping(taskId: task.id)
            }
            return
        }

        let event: EKEvent
        if let existing = existingEvent {
            event = existing
        } else {
            event = EKEvent(eventStore: calendarManager.store)
            event.calendar = calendar
        }

        // Apply task data to event
        TaskEventMapper.apply(task: task, to: event)
        // If mapper didn't set any dates (e.g., task has no due date), skip saving to avoid invalid events
        guard event.startDate != nil && event.endDate != nil else { return }


        // Save event
        try calendarManager.save(event)

        // Update ID mapping
        idMap.addMapping(taskId: task.id, eventId: event.eventIdentifier)
    }

    private func processPatch(_ patch: TaskPatch, in calendar: EKCalendar, window: DateInterval) async throws {
        guard let api = api else {
            throw CalendarSyncError.apiError("API not configured")
        }

        let serverTask = try await api.patchTask(patch)

        // Refresh event's signature to acknowledge write
        if let event = calendarManager.findEvent(
            byTaskId: serverTask.id,
            in: calendar,
            window: window,
            idMap: idMap
        ) {
            TaskEventMapper.apply(task: serverTask, to: event)
            try calendarManager.save(event)
        }

        print("📅 Processed patch for task \(patch.id)")
    }

    // MARK: - Event Store Notifications

    private func setupEventStoreNotifications() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: calendarManager.store,
            queue: .main
        ) { [weak self] _ in
            self?.handleEventStoreChanged()
        }
    }

    private func handleEventStoreChanged() {
        guard isEnabled, readWriteEnabled else { return }

        // Debounce to avoid excessive syncing
        debouncer.call(after: 2.0) { [weak self] in
            Task { @MainActor in
                await self?.syncNow(mode: .twoWay)
            }
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
        readWriteEnabled = UserDefaults.standard.bool(forKey: "calendarSyncReadWriteEnabled")

        // Load enabled list IDs (placeholder)
        enabledListIDs = UserDefaults.standard.stringArray(forKey: "calendarSyncEnabledLists") ?? []
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "calendarSyncEnabled")
        UserDefaults.standard.set(readWriteEnabled, forKey: "calendarSyncReadWriteEnabled")
        UserDefaults.standard.set(enabledListIDs, forKey: "calendarSyncEnabledLists")
    }

    // MARK: - Error Management

    func clearErrors() {
        syncErrors.removeAll()
    }

    // MARK: - Configuration

    func setReadWriteEnabled(_ enabled: Bool) {
        readWriteEnabled = enabled
        saveSettings()
    }

    func setEnabledLists(_ listIDs: [String]) {
        enabledListIDs = listIDs
        saveSettings()
    }
}
