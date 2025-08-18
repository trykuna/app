// Services/BackgroundTaskChangeDetector.swift
import Foundation

struct BackgroundSyncState: Codable {
    var lastCursorISO8601: String?
    // Track last seen updatedAt per task to avoid repeated updated notifications
    var lastSeenUpdatedISO: [Int: String] = [:]
}

@MainActor
final class BackgroundTaskChangeDetector {
    private let userDefaults = UserDefaults.standard
    private let stateKey = "BackgroundSyncStateV1"

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
            if lastSeen == nil {
                summary.newTasks.append(t)
            } else if let s = updatedISO, s > lastSeen! {
                summary.updatedTasks.append(t)
            }

            if let uid = currentUserId, let assignees = t.assignees, assignees.contains(where: { $0.id == uid }) {
                summary.assignedToMe.append(t)
            }

            if settings.notifyLabelsUpdated, let labels = t.labels {
                let hasWatched = labels.contains(where: { watched.contains($0.id) })
                if hasWatched { summary.labelWatched.append(t) }
            }

            if let s = updatedISO { state.lastSeenUpdatedISO[t.id] = s }
        }

        // Update and persist cursor
        if let maxC = summary.maxCursorISO8601 { state.lastCursorISO8601 = maxC }
        saveState(state)

        return summary
    }
}

