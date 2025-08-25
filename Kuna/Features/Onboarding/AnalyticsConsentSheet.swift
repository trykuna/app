// Features/Onboarding/AnalyticsConsentSheet.swift
import SwiftUI

struct AnalyticsConsentSheet: View {
    @EnvironmentObject var appSettings: AppSettings
    let privacyURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)

                // Text("Anonymous Analytics")
                Text(String(localized: "analytics_consent_title", comment: "Title for analytics consent sheet"))
                    .font(.title2).bold()

                // Text("We'd like to collect anonymous usage analytics to help improve the app. No personal data is collected, nothing is shared with advertisers, and it's only used to improve features.")
                Text(String(localized: "analytics_consent_text", comment: "Text for analytics consent sheet"))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: { openPrivacy() }) {
                        SwiftUI.Label("Privacy Policy", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                Spacer()

                VStack(spacing: 10) {
                    Button(action: allow) {
                        Text(String(localized: "analytics_consent_allow_button", comment: "Button for allowing analytics")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel, action: deny) {
                        Text(String(localized: "analytics_consent_deny_button", comment: "Button for denying analytics")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            // .navigationTitle("Help Improve Kuna")
            .navigationTitle(String(localized: "analytics_consent_title", comment: "Title for analytics consent sheet"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openPrivacy() {
        #if canImport(UIKit)
        UIApplication.shared.open(privacyURL)
        #endif
    }

    private func allow() {
        Analytics.setEnabled(true)
        Analytics.recordConsent(.granted)
        dismiss()
    }

    private func deny() {
        Analytics.setEnabled(false)
        Analytics.recordConsent(.denied)
        dismiss()
    }
}

