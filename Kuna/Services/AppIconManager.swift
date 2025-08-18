// Services/AppIconManager.swift
import UIKit
import SwiftUI

enum AppIcon: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case gold = "Gold"
    case orange = "Orange"
    case red = "Red"
    case yellow = "Yellow"
    case neon = "Neon"
    case silver = "Silver"
    case pride = "Pride"
    case altPride = "AltPride"
    case transPride = "TransPride"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .gold: return "Gold"
        case .orange: return "Orange"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .neon: return "Neon"
        case .silver: return "Silver"
        case .pride: return "Pride"
        case .altPride: return "Alt Pride"
        case .transPride: return "Trans Pride"
        }
    }

    var description: String {
        switch self {
        case .default: return "The original Kuna icon"
        case .gold: return "Elegant and premium"
        case .orange: return "Energetic and vibrant"
        case .red: return "Bold and powerful"
        case .yellow: return "Bright and cheerful"
        case .neon: return "Electric and modern"
        case .silver: return "Sleek and professional"
        case .pride: return "Celebrate diversity"
        case .altPride: return "Alternative pride design"
        case .transPride: return "Trans pride colors"
        }
    }

    var logoVariant: LogoVariant {
        switch self {
        case .default: return .main
        case .gold: return .gold
        case .orange: return .orange
        case .red: return .red
        case .yellow: return .yellow
        case .neon: return .neon
        case .silver: return .silver
        case .pride: return .pride
        case .altPride: return .altPride
        case .transPride: return .transPride
        }
    }

    var previewImageName: String {
        // Use the logo variant's light image as preview
        return logoVariant.lightImageName
    }

    var alternateIconName: String? {
        switch self {
        case .default: return nil // nil means default icon
        case .gold: return "AppIcon-Gold"
        case .orange: return "AppIcon-Orange"
        case .red: return "AppIcon-Red"
        case .yellow: return "AppIcon-Yellow"
        case .neon: return "AppIcon-Neon"
        case .silver: return "AppIcon-Silver"
        case .pride: return "AppIcon-Pride"
        case .altPride: return "AppIcon-AltPride"
        case .transPride: return "AppIcon-TransPride"
        }
    }

    var accentColor: Color {
        switch self {
        case .default: return .blue
        case .gold: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .yellow: return .yellow
        case .neon: return .cyan
        case .silver: return .gray
        case .pride: return .pink
        case .altPride: return .purple
        case .transPride: return .cyan
        }
    }
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published var currentIcon: AppIcon = .default
    @Published var isChangingIcon = false

    private init() {
        updateCurrentIcon()
    }

    var supportsAlternateIcons: Bool {
        if #available(iOS 10.3, *) {
            // Prefer runtime check of Info.plist to avoid false negatives
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let alternates = icons["CFBundleAlternateIcons"] as? [String: Any],
               !alternates.isEmpty {
                return true
            }
            return UIApplication.shared.supportsAlternateIcons
        } else {
            return false
        }
    }

    func updateCurrentIcon() {
        let currentIconName = UIApplication.shared.alternateIconName
        currentIcon = AppIcon.allCases.first { $0.alternateIconName == currentIconName } ?? .default
    }

    private func declaredAlternateIconNames() -> [String] {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternates = icons["CFBundleAlternateIcons"] as? [String: Any] else { return [] }
        return Array(alternates.keys)
    }

    func setIcon(_ icon: AppIcon) async throws {
        let previous = currentIcon

        guard supportsAlternateIcons else {
            Analytics.trackIconChange(from: previous, to: icon, outcome: "unsupported", ms: 0)
            throw AppIconError.notSupported
        }

        guard icon != previous else {
            // No change; still useful to know if users tap the same icon again
            Analytics.trackIconChange(from: previous, to: icon, outcome: "noop", ms: 0)
            return
        }

        isChangingIcon = true
        let t0 = Date()
        defer { isChangingIcon = false }

        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
            currentIcon = icon
            UserDefaults.standard.set(icon.rawValue, forKey: "selectedAppIcon")

            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.trackIconChange(from: previous, to: icon, outcome: "success", ms: ms)
            if previous != .default { Analytics.trackIconState(previous, enabled: false) }
            if icon != .default { Analytics.trackIconState(icon, enabled: true) }
        } catch {
            let ms = Date().timeIntervalSince(t0) * 1000
            Analytics.trackIconChange(from: previous, to: icon, outcome: "failure", error: error.localizedDescription, ms: ms)
            throw AppIconError.changeFailed(error.localizedDescription)
        }
    }

    func restoreSelectedIcon() {
        if let savedIconName = UserDefaults.standard.string(forKey: "selectedAppIcon"),
           let savedIcon = AppIcon(rawValue: savedIconName) {
            Task {
                // setIcon handles all analytics; if it fails we don't want to crash
                try? await setIcon(savedIcon)
            }
        }
    }
}

enum AppIconError: LocalizedError {
    case notSupported
    case changeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Alternate app icons are not supported on this device"
        case .changeFailed(let message):
            return "Failed to change app icon: \(message)"
        }
    }
}
