// Services/BackgroundSyncService.swift
import Foundation
import BackgroundTasks

@MainActor
final class BackgroundSyncService: ObservableObject {
    static let shared = BackgroundSyncService()

    enum Frequency: String, CaseIterable, Identifiable {
        #if DEBUG
        case s30 = "30s"
        case m1  = "1m"
        #endif
        case m15 = "15m"
        case m30 = "30m"
        case h1 = "1h"
        case h6 = "6h"
        case h12 = "12h"
        case h24 = "24h"
        var id: String { rawValue }

        var timeInterval: TimeInterval {
            switch self {
            #if DEBUG
            case .s30: return 30
            case .m1:  return 60
            #endif
            case .m15: return 15 * 60
            case .m30: return 30 * 60
            case .h1:  return 60 * 60
            case .h6:  return 6 * 60 * 60
            case .h12: return 12 * 60 * 60
            case .h24: return 24 * 60 * 60
            }
        }
    }

    // Use the identifier from Info.plist if present to avoid case mismatches across environments
    var taskIdentifier: String {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String],
           let id = ids.first(where: { $0.hasSuffix(".bg.refresh") }) {
            return id
        }
        return (Bundle.main.bundleIdentifier ?? "tech.systemsmystery.kuna") + ".bg.refresh"
    }

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    #if DEBUG
    private func logBGEnvironment(prefix: String) {
        let plist = Bundle.main.infoDictionary ?? [:]
        let ids = plist["BGTaskSchedulerPermittedIdentifiers"] as? [String] ?? []
        let modes = plist["UIBackgroundModes"] as? [String] ?? []
        Log.app.debug("BG[")
        Log.app.debug("\(prefix) id=\(self.taskIdentifier, privacy: .public)")
        Log.app.debug("Permitted IDs in Info.plist: \(ids.joined(separator: ", "), privacy: .public)")
        Log.app.debug("UIBackgroundModes: \(modes.joined(separator: ", "), privacy: .public)")
    }
    #endif

    func scheduleNext(after frequency: Frequency) {
        // Cancel any existing request for this identifier to avoid tooManyPendingTaskRequests
        // BGTaskScheduler requires at least 15 minutes for BGAppRefresh on device.
        // For debug intervals under 15 minutes, the scheduler may reject or defer.
        // We still submit to let the system decide, but this can return Code=3 on device.

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: self.taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(frequency.timeInterval)
        #if DEBUG
        logBGEnvironment(prefix: "scheduleNext")
        #endif
        do { try BGTaskScheduler.shared.submit(request) } catch {
            Log.app.error("BG: submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        Log.app.debug("BG: app refresh handler invoked")
        scheduleNext(after: AppSettings.shared.backgroundSyncFrequency)

        let syncTask = Task {
            await runSync()
        }
        
        task.expirationHandler = {
            Log.app.error("BG: task expired - cancelling sync")
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }

        Task {
            await syncTask.value
            Log.app.debug("BG: runSync completed successfully")
            task.setTaskCompleted(success: true)
        }
    }

    private func runSync() async {
        Log.app.debug("BG: runSync started")
        // Save last sync attempt time for debugging
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackgroundSyncAttempt")
        
        // Build an API instance from persisted server URL + token to avoid needing AppState
        guard let server = Keychain.readServerURL(), let _ = Keychain.readToken(), let apiBase = try? AppState.buildAPIURL(from: server) else { 
            Log.app.error("BG: runSync failed - missing server URL or token")
            return 
        }
        let api = VikunjaAPI(config: .init(baseURL: apiBase), tokenProvider: { Keychain.readToken() })
        let settings = AppSettings.shared
        // Pagination window to avoid huge payloads
        let _ = 200 // pageSize - kept for documentation but not currently used

        guard settings.backgroundSyncEnabled else { Log.app.debug("BG: runSync aborted — background sync disabled"); return }

        let detector = BackgroundTaskChangeDetector.shared
        // Determine current user ID from token (sub) if available
        var currentUserId: Int? = nil
        if let token = Keychain.readToken(), let payload = try? JWTDecoder.decode(token), let sub = payload.sub, let id = Int(sub) {
            currentUserId = id
            Log.app.debug("BG: Current user ID: \(id)")
        } else {
            Log.app.warning("BG: Could not determine current user ID - assignment notifications won't work")
        }

        do {
            let summary = try await detector.detectChanges(api: api, currentUserId: currentUserId, settings: settings)
            Log.app.debug("BG: changes new:\(summary.newTasks.count) updated:\(summary.updatedTasks.count) assigned:\(summary.assignedToMe.count) labels:\(summary.labelWatched.count)")
            // Notifications per user toggles
            let notifier = NotificationsManager.shared
            // Request permission if needed when any toggle is enabled
            if settings.notifyNewTasks || settings.notifyUpdatedTasks || settings.notifyAssignedToMe || settings.notifyLabelsUpdated || settings.notifyWithSummary {
                _ = await notifier.requestAuthorizationIfNeeded()
            }

            if settings.notifyNewTasks {
                Log.app.debug("BG: Sending \(summary.newTasks.count) new task notifications")
                for t in summary.newTasks {
                    Log.app.debug("BG: New task notification - \(t.title)")
                    notifier.postImmediate(title: "New Task", body: t.title, thread: "tasks.new", userInfo: ["taskId": t.id])
                }
            }
            if settings.notifyUpdatedTasks {
                Log.app.debug("BG: Sending \(summary.updatedTasks.count) updated task notifications")
                for t in summary.updatedTasks {
                    Log.app.debug("BG: Updated task notification - \(t.title)")
                    notifier.postImmediate(title: "Task Updated", body: t.title, thread: "tasks.updated", userInfo: ["taskId": t.id])
                }
            }
            if settings.notifyAssignedToMe, let uid = currentUserId {
                Log.app.debug("BG: Sending \(summary.assignedToMe.count) assignment notifications for user \(uid)")
                for t in summary.assignedToMe {
                    Log.app.debug("BG: Assignment notification - \(t.title)")
                    notifier.postImmediate(title: "Assigned to You", body: t.title, thread: "tasks.assigned", userInfo: ["taskId": t.id])
                }
            }
            if settings.notifyLabelsUpdated {
                Log.app.debug("BG: Sending \(summary.labelWatched.count) label watch notifications")
                for t in summary.labelWatched {
                    Log.app.debug("BG: Label watch notification - \(t.title)")
                    notifier.postImmediate(title: "Watched Label Updated", body: t.title, thread: "tasks.labels", userInfo: ["taskId": t.id])
                }
            }

            if settings.notifyWithSummary {
                let n = summary.newTasks.count
                let u = summary.updatedTasks.count
                if n > 0 || u > 0 {
                    let body = "New: \(n), Updated: \(u)"
                    Log.app.debug("BG: Sending summary notification - \(body)")
                    notifier.postImmediate(title: "Task Changes", body: body, thread: "tasks.summary")
                } else {
                    Log.app.debug("BG: No changes for summary notification")
                }
            }
            // Save successful sync time
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackgroundSyncSuccess")
            Log.app.debug("BG: sync completed successfully")
        } catch {
            Log.app.error("BG: sync failed: \(String(describing: error), privacy: .public)")
        }
    }

    #if DEBUG
    /// Manually trigger a foreground sync for testing.
    func runSyncNowForTesting() async {
        await runSync()
    }
    #endif

}

