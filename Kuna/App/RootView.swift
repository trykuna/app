// App/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var settings = AppSettings.shared
    @State private var showAnalyticsConsent = false

    private let privacyUrl = URL(string: "https://trykuna.app/privacy.html")! // swiftlint:disable:this force_unwrapping

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
            AnalyticsConsentSheet(privacyURL: privacyUrl)
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
