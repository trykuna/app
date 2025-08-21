import Foundation
import EventKit

@MainActor
final class CalendarSyncEngine: ObservableObject {

    // MARK: - Dependencies

    private let calendarManager = CalendarManager()
    private let persistence = SyncStatePersistence()
    private let debouncer = Debouncer()
    private var api: CalendarSyncAPI?

    // MARK: - State (UI)
    @Published var isEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []
    @Published var readWriteEnabled: Bool = false

    // MARK: - Internal state
    private var syncState: CalendarSyncState
    private var idMap: IdMap
    private var kunaCalendar: EKCalendar?
    private var projectMap: ProjectCalendarMap

    // Settings
    private var enabledListIDs: [String] = []      // Which projects to sync (list IDs)
    private var perProjectEnabled: Bool = false    // Advanced toggle

    // Counters for “event count” summary
    private var createdCount = 0
    private var updatedCount = 0
    private var removedCount = 0

    // MARK: - Initialization

    init() {
        self.syncState = persistence.loadSyncState()
        self.idMap = persistence.loadIdMap()
        self.projectMap = persistence.loadProjectCalendarMap()
        self.lastSyncDate = syncState.lastLocalScanAt

        loadSettings()
        setupEventStoreNotifications()
    }

    // MARK: - Configuration

    func setAPI(_ api: CalendarSyncAPI) {
        self.api = api
    }

    // MARK: - Public Interface

    func enable() async throws {
        guard !isEnabled else { return }

        let hasAccess = try await calendarManager.requestAccess()
        guard hasAccess else { throw CalendarError.accessDenied }

        if !perProjectEnabled {
            kunaCalendar = try calendarManager.ensureKunaCalendar()
        }
        isEnabled = true
        saveSettings()

        await performInitialSync()
    }

    /// Turn off sync and **remove** Kuna-tagged calendar entries (all Kuna calendars).
    func disable() {
        Task {
            await CalendarSyncService.shared.tidyUpAllKunaCalendars()
        }
        isEnabled = false
        kunaCalendar = nil
        saveSettings()
        persistence.clearAllData()
        projectMap = ProjectCalendarMap()
    }

    func setPerProjectEnabled(_ enabled: Bool) {
        perProjectEnabled = enabled
        persistence.savePerProjectEnabled(enabled)
    }

    func setReadWriteEnabled(_ enabled: Bool) {
        readWriteEnabled = enabled
        saveSettings()
    }

    func setEnabledLists(_ listIDs: [String]) {
        enabledListIDs = listIDs
        persistence.saveEnabledListIDs(listIDs)
        saveSettings()
    }

    func syncNow(mode: SyncMode = .pullOnly) async {
        guard isEnabled, !isSyncing else { return }

        isSyncing = true
        createdCount = 0; updatedCount = 0; removedCount = 0
        defer { isSyncing = false }

        do {
            try await performSync(mode: mode)
            lastSyncDate = Date()
            Log.app.debug("📅 Sync summary — created: \(self.createdCount) • updated: \(self.updatedCount) • removed: \(self.removedCount)")
        } catch {
            syncErrors.append("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Implementation

    private func performInitialSync() async {
        syncState = CalendarSyncState()
        idMap = IdMap()
        await syncNow(mode: .pullOnly)
    }

    private func performSync(mode: SyncMode) async throws {
        let window = SyncConst.rollingWindow()

        if perProjectEnabled {
            try await performPullPerProject(window: window)
        } else {
            let calendar: EKCalendar
            if let existingCalendar = kunaCalendar {
                calendar = existingCalendar
            } else {
                let newCalendar = try calendarManager.ensureKunaCalendar()
                kunaCalendar = newCalendar
                calendar = newCalendar
            }
            try await performPull(calendar: calendar, window: window)
        }

        if mode == .twoWay && readWriteEnabled {
            // Two-way push is only supported for a single calendar (for now).
            if !perProjectEnabled, let cal = kunaCalendar {
                try await performPush(calendar: cal)
            }
        }

        persistence.saveSyncState(syncState)
        persistence.saveIdMap(idMap)
        persistence.saveProjectCalendarMap(projectMap)
    }

    private func performPull(calendar: EKCalendar, window: DateInterval) async throws {
        guard let api = api else { throw CalendarSyncError.apiError("API not configured") }

        let tasks = try await api.fetchTasks(
            updatedSince: syncState.remoteCursorISO8601,
            listIDs: enabledListIDs,
            window: window
        )

        for task in tasks {
            try await upsertEvent(for: task, in: calendar, window: window)
            syncState.remoteCursorISO8601 = maxISO8601(syncState.remoteCursorISO8601, task.updatedAtISO8601)
        }
        Log.app.debug("📅 Pull (single calendar) processed \(tasks.count) tasks")
    }

    private func performPullPerProject(window: DateInterval) async throws {
        guard let api = api else { throw CalendarSyncError.apiError("API not configured") }

        let tasks = try await api.fetchTasks(
            updatedSince: syncState.remoteCursorISO8601,
            listIDs: enabledListIDs,
            window: window
        )

        // Soft cap warning
        let uniqueProjects = Set(tasks.map { $0.projectId })
        if uniqueProjects.count > SyncConst.perProjectSoftCap {
            syncErrors.append("Per‑project calendars exceed \(SyncConst.perProjectSoftCap). Consider using a single calendar for performance.")
        }

        // Group by project
        let grouped = Dictionary(grouping: tasks, by: { $0.projectId })
        for (pid, items) in grouped {
            let projTitle = items.first?.projectTitle ?? "Project \(pid)"
            let calendar: EKCalendar
            if let existingId = projectMap.calendarId(for: pid),
               let existing = calendarManager.store.calendar(withIdentifier: existingId) {
                calendar = existing
            } else {
                let cal = try calendarManager.ensureProjectCalendar(projectId: pid, projectTitle: projTitle)
                projectMap.set(projectId: pid, calendarId: cal.calendarIdentifier)
                calendar = cal
            }
            for task in items {
                try await upsertEvent(for: task, in: calendar, window: window)
                syncState.remoteCursorISO8601 = maxISO8601(syncState.remoteCursorISO8601, task.updatedAtISO8601)
            }
        }
        Log.app.debug("📅 Pull (per‑project) processed \(tasks.count) tasks across \(uniqueProjects.count) projects")
    }

    private func performPush(calendar: EKCalendar) async throws {
        let pushWindow = SyncConst.pushWindow()
        let changedEvents = calendarManager.eventsChangedSince(syncState.lastLocalScanAt, in: calendar, within: pushWindow)

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
        Log.app.debug("📅 Push completed, processed \(patches.count) changes")
    }

    // MARK: - Event Operations

    private func upsertEvent(for task: CalendarSyncTask, in calendar: EKCalendar, window: DateInterval) async throws {
        let existingEvent = calendarManager.findEvent(byTaskId: task.id, in: calendar, window: window, idMap: idMap)

        if task.deleted {
            if let event = existingEvent {
                try calendarManager.remove(event)
                removedCount += 1
                idMap.removeMapping(taskId: task.id)
            }
            return
        }

        let event: EKEvent
        let isCreate: Bool
        if let existing = existingEvent {
            event = existing
            isCreate = false
        } else {
            event = EKEvent(eventStore: calendarManager.store)
            event.calendar = calendar
            isCreate = true
        }

        TaskEventMapper.apply(task: task, to: event)
        guard event.startDate != nil && event.endDate != nil else { return }

        try calendarManager.save(event)
        if isCreate { createdCount += 1 } else { updatedCount += 1 }
        idMap.addMapping(taskId: task.id, eventId: event.eventIdentifier)
    }

    private func processPatch(_ patch: TaskPatch, in calendar: EKCalendar, window: DateInterval) async throws {
        guard let api = api else { throw CalendarSyncError.apiError("API not configured") }
        let serverTask = try await api.patchTask(patch)
        if let event = calendarManager.findEvent(byTaskId: serverTask.id, in: calendar, window: window, idMap: idMap) {
            TaskEventMapper.apply(task: serverTask, to: event)
            try calendarManager.save(event)
            updatedCount += 1
        }
        Log.app.debug("📅 Processed patch for task \(patch.id)")
    }

    // MARK: - Event Store Notifications

    private func setupEventStoreNotifications() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: calendarManager.store,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.handleEventStoreChanged() }
        }
    }

    private func handleEventStoreChanged() {
        guard isEnabled, readWriteEnabled, !perProjectEnabled else { return }
        debouncer.call(after: 2.0) { [weak self] in
            Task { @MainActor in await self?.syncNow(mode: .twoWay) }
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
        readWriteEnabled = UserDefaults.standard.bool(forKey: "calendarSyncReadWriteEnabled")
        enabledListIDs = persistence.loadEnabledListIDs()
        perProjectEnabled = persistence.loadPerProjectEnabled()
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "calendarSyncEnabled")
        UserDefaults.standard.set(readWriteEnabled, forKey: "calendarSyncReadWriteEnabled")
        persistence.saveEnabledListIDs(enabledListIDs)
        persistence.savePerProjectEnabled(perProjectEnabled)
    }

    // MARK: - Errors

    func clearErrors() { syncErrors.removeAll() }
}
