// App/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var settings = AppSettings.shared
    @State private var showAnalyticsConsent = false

    var body: some View {
        Group {
            if app.isAuthenticated, let api = app.api {
                MainContainerView(api: api)
            } else {
                LoginView()
            }
        }
        .onAppear(perform: maybeShowAnalyticsConsent)
        .sheet(isPresented: $showAnalyticsConsent) {
            AnalyticsConsentSheet(privacyURL: URL(string: "https://systemsmystery.tech/privacy")!)
                .environmentObject(settings)
        }
    }

    private func maybeShowAnalyticsConsent() {
        // Show only if no decision recorded yet
        if settings.analyticsConsentDecision == nil {
            showAnalyticsConsent = true
        }
    }
}
