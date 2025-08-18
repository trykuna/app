// Services/Analytics.swift
import Foundation
import TelemetryDeck
import SwiftUI

enum AnalyticsConsent: String { case granted, denied }

@MainActor
enum Analytics {
    static func isEnabled() -> Bool {
        // Avoid referencing AppSettings.shared here to prevent reentrancy during singleton init
        // Source of truth is persisted in UserDefaults
        return UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        AppSettings.shared.analyticsEnabled = enabled
    }

    static func recordConsent(_ consent: AnalyticsConsent) {
        AppSettings.shared.analyticsConsentDecision = consent.rawValue
        track("analytics_consent", parameters: ["decision": consent.rawValue])
    }

    static func track(_ event: String,
                      parameters: [String: String] = [:],
                      floatValue: Double? = nil) {
        guard isEnabled() else { return }
        TelemetryDeck.signal(event,
                             parameters: parameters,
                             floatValue: floatValue)
    }
    
    static func trackSettingToggle(_ name: String, enabled: Bool) {
        track(
            "setting_changed",
            parameters: [
                "setting": name,
                "value": enabled ? "on" : "off"
            ]
        )
    }
    static func trackIconChange(from: AppIcon, to: AppIcon, outcome: String, error: String? = nil, ms: Double) {
        var params: [String: String] = [
            "from": from.rawValue,
            "to": to.rawValue,
            "outcome": outcome,
            "duration_ms": String(Int(ms))
        ]
        if let error { params["error"] = error }
        track("Settings.Icon.Changed", parameters: params, floatValue: ms)
    }

    static func trackIconState(_ icon: AppIcon, enabled: Bool) {
        trackSettingToggle("Settings.Icon.\(icon.rawValue)", enabled: enabled)
    }
}
