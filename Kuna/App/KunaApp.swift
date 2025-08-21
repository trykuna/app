// App/KunaApp.swift
import SwiftUI
import TelemetryDeck

@main
struct KunaApp: App {
    init() {
        let config = TelemetryDeck.Config(appID: "8985B61F-3FAE-4143-9791-CB891B837EB1")
        config.defaultSignalPrefix = "Kuna."
        #if DEBUG
        config.testMode = true
        #endif
        // Initialize TelemetryDeck; Analytics wrapper will gate sending based on user preference
        TelemetryDeck.initialize(config: config)

        // Register background tasks as early as possible (Apple recommends during app launch)
        BackgroundSyncService.shared.register()
        
        // Schedule initial background sync if enabled
        let settings = AppSettings.shared
        if settings.backgroundSyncEnabled {
            BackgroundSyncService.shared.scheduleNext(after: settings.backgroundSyncFrequency)
        }
    }
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onAppear {
                    // Restore selected app icon on app launch
                    AppIconManager.shared.restoreSelectedIcon()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    // Rate limit memory warning handling to prevent infinite loops
                    let lastWarning = UserDefaults.standard.double(forKey: "lastMemoryWarningTime")
                    let now = Date().timeIntervalSince1970
                    
                    // Only handle if it's been at least 5 seconds since last warning
                    guard now - lastWarning > 5.0 else {
                        Log.app.debug("Memory warning rate limited - skipping")
                        return
                    }
                    
                    UserDefaults.standard.set(now, forKey: "lastMemoryWarningTime")
                    Log.app.warning("App: Received memory warning - clearing caches")
                    appState.handleMemoryWarning()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    Log.app.debug("App: Entered background - performing memory cleanup and scheduling background sync")
                    // Aggressive memory cleanup when app goes to background
                    appState.handleMemoryWarning()
                    CommentCountManager.shared?.clearCache()
                    WidgetCacheWriter.performMemoryCleanup()
                    BackgroundTaskChangeDetector.shared.performMemoryCleanup()
                    // Re-schedule background refresh when moving to background (recommended)
                    let settings = AppSettings.shared
                    if settings.backgroundSyncEnabled {
                        BackgroundSyncService.shared.scheduleNext(after: settings.backgroundSyncFrequency)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Log.app.debug("App: Entering foreground")
                    // Optional: Refresh critical data when returning to foreground
                }
                .onOpenURL { url in
                    guard url.scheme == "kuna", url.host == "task" else { return }
                    if let id = Int(url.lastPathComponent) {
                        appState.deepLinkTaskId = id
                    }
                }
        }
    }
}

