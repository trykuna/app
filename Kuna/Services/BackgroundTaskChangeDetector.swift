// Services/BackgroundTaskChangeDetector.swift
import Foundation

struct BackgroundSyncState: Codable {
    var lastCursorISO8601: String?
    // Track last seen updatedAt per task to avoid repeated updated notifications
    var lastSeenUpdatedISO: [Int: String] = [:]
    
    // Clean up old entries to prevent memory leaks
    mutating func cleanupOldEntries(keepingTaskIds: Set<Int>) {
        let oldCount = lastSeenUpdatedISO.count
        lastSeenUpdatedISO = lastSeenUpdatedISO.filter { keepingTaskIds.contains($0.key) }
        let newCount = lastSeenUpdatedISO.count
        if oldCount != newCount {
            Log.app.debug("BG: Cleaned up \(oldCount - newCount) old task tracking entries")
        }
    }
}

@MainActor
final class BackgroundTaskChangeDetector {
    static let shared = BackgroundTaskChangeDetector()
    private let userDefaults = UserDefaults.standard
    private let stateKey = "BackgroundSyncStateV1"
    
    private init() {} // Singleton

    func loadState() -> BackgroundSyncState {
        if let data = userDefaults.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(BackgroundSyncState.self, from: data) {
            return state
        }
        return BackgroundSyncState()
    }

    func saveState(_ state: BackgroundSyncState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: stateKey)
        } catch {
            Log.app.error("BG: Failed to save background sync state: \(String(describing: error), privacy: .public)")
        }
    }

    struct ChangeSummary {
        var newTasks: [VikunjaTask] = []
        var updatedTasks: [VikunjaTask] = []
        var assignedToMe: [VikunjaTask] = []
        var labelWatched: [VikunjaTask] = []
        var maxCursorISO8601: String?
    }

    func detectChanges(api: VikunjaAPI, currentUserId: Int?, settings: AppSettings) async throws -> ChangeSummary {
        var state = loadState()
        let since = state.lastCursorISO8601
        let isFirstSync = since == nil

        // Fetch tasks updated since (best effort); fall back to all and filter client-side
        let tasks = try await api.fetchAllTasksUpdatedSince(sinceISO8601: since)

        var summary = ChangeSummary()
        let watched = Set(settings.watchedLabelIDs)
        let iso = ISO8601DateFormatter()

        for t in tasks {
            // Track max cursor from updatedAt
            var updatedISO: String? = nil
            if let u = t.updatedAt {
                let s = iso.string(from: u)
                updatedISO = s
                if let maxS = summary.maxCursorISO8601 {
                    if s > maxS { summary.maxCursorISO8601 = s }
                } else { summary.maxCursorISO8601 = s }
            }

            // New vs updated logic using per-task lastSeenUpdatedISO
            let lastSeen = state.lastSeenUpdatedISO[t.id]
            var isNewTask = false
            var isUpdatedTask = false
            
            if lastSeen == nil {
                // On first sync, don't treat existing tasks as "new" for notifications
                if !isFirstSync {
                    summary.newTasks.append(t)
                    isNewTask = true
                }
            } else if let s = updatedISO, s > lastSeen! {
                summary.updatedTasks.append(t)
                isUpdatedTask = true
            }

            // Only notify about assignments/labels for new or updated tasks (and not on first sync)
            if (isNewTask || isUpdatedTask) && !isFirstSync {
                if let uid = currentUserId, let assignees = t.assignees, assignees.contains(where: { $0.id == uid }) {
                    Log.app.debug("BG: Task '\(t.title)' assigned to user \(uid)")
                    summary.assignedToMe.append(t)
                }

                if settings.notifyLabelsUpdated, let labels = t.labels {
                    let hasWatched = labels.contains(where: { watched.contains($0.id) })
                    if hasWatched { 
                        Log.app.debug("BG: Task '\(t.title)' has watched label")
                        summary.labelWatched.append(t) 
                    }
                }
            }

            if let s = updatedISO { state.lastSeenUpdatedISO[t.id] = s }
        }

        // Update and persist cursor
        if let maxC = summary.maxCursorISO8601 { state.lastCursorISO8601 = maxC }
        
        // Clean up old task tracking entries to prevent memory leaks
        let currentTaskIds = Set(tasks.map { $0.id })
        state.cleanupOldEntries(keepingTaskIds: currentTaskIds)
        
        saveState(state)

        if isFirstSync {
            Log.app.debug("BG: First sync completed - no notifications sent for existing tasks")
        }

        return summary
    }
    
    func performMemoryCleanup() {
        Log.app.debug("BackgroundTaskChangeDetector: Performing memory cleanup")
        
        var state = loadState()
        let oldCount = state.lastSeenUpdatedISO.count
        
        // Keep only the most recent 100 task tracking entries to prevent memory leaks
        if oldCount > 100 {
            let sortedEntries = state.lastSeenUpdatedISO.sorted { $0.value > $1.value }
            state.lastSeenUpdatedISO = Dictionary(uniqueKeysWithValues: Array(sortedEntries.prefix(100)))
            
            saveState(state)
            Log.app.debug("BackgroundTaskChangeDetector: Trimmed task tracking from \(oldCount) to \(state.lastSeenUpdatedISO.count) entries")
        }
    }
}

