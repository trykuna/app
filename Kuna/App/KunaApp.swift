// App/KunaApp.swift
import SwiftUI

@main
struct KunaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

