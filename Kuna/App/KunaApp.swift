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
    }
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onAppear {
                    // Schedule if enabled (registration already done in init)
                    let s = AppSettings.shared
                    if s.backgroundSyncEnabled {
                        BackgroundSyncService.shared.scheduleNext(after: s.backgroundSyncFrequency)
                    }
                    // Restore selected app icon on app launch
                    AppIconManager.shared.restoreSelectedIcon()
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

