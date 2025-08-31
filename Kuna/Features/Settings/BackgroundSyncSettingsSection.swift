// Features/Settings/BackgroundSyncSettingsSection.swift
import SwiftUI
import UserNotifications

struct BackgroundSyncSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var settings: AppSettings
    @StateObject private var notifications = NotificationsManager.shared

    var body: some View {
        Section {
            Toggle(isOn: $settings.backgroundSyncEnabled) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.blue).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        // Text("Background Sync").font(.body)
                        Text(String(localized: "settings.backgroundSync.title", comment: "Title for background sync"))
                        // Text("Sync tasks periodically in the background")
                        Text(String(localized: "settings.backgroundSync.subtitle", comment: "Subtitle for background sync"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            if settings.backgroundSyncEnabled {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        // Text("Frequency").font(.body)
                        Text(String(localized: "settings.backgroundSync.frequency.title", comment: "Title for background sync frequency"))
                        // Text("How often to refresh tasks in background")
                        Text(String(localized: "settings.backgroundSync.frequency.subtitle", comment: "Subtitle for background sync frequency"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.backgroundSyncFrequency) {
                        Text(String(localized: "settings.backgroundSync.frequency.15m", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.30m", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.1h", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.1h", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.6h", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.12h", comment: "Frequency for background sync"))
                        Text(String(localized: "settings.backgroundSync.frequency.24h", comment: "Frequency for background sync"))
                    }.pickerStyle(.menu)
                }
                HStack {
                    Image(systemName: notifications.authorizationStatus == .authorized ? "bell.badge.fill" : "bell.badge")
                        .foregroundColor(notifications.authorizationStatus == .authorized ? .green : .orange)
                    // TODO: Localize
                    Text("settings.backgroundSync.notifications \(statusText)",
                         comment: "Label in Background Sync settings showing the notifications status. Placeholder is the status text (e.g. Enabled, Disabled)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if notifications.authorizationStatus == .notDetermined || notifications.authorizationStatus == .denied {
                        // Button("Enable") {
                        Button(String(localized: "common.enable", comment: "Enable button")) {
                            Task { _ = await notifications.requestAuthorizationIfNeeded() }
                        }
                        .buttonStyle(.bordered)
                    }
                }


                Toggle(isOn: $settings.notifyNewTasks) {
                    // SwiftUI.Label("Notify on new tasks", systemImage: "bell.badge")
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyNewTasks", comment: "Notify on new tasks toggle"), systemImage: "bell.badge")
                }
                Toggle(isOn: $settings.notifyUpdatedTasks) {
                    // SwiftUI.Label("Notify on updated tasks", systemImage: "bell")
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyUpdatedTasks", comment: "Notify on updated tasks toggle"), systemImage: "bell")
                }
                Toggle(isOn: $settings.notifyAssignedToMe) {
                    // SwiftUI.Label("Notify when assigned to me", systemImage: "person.fill.badge.plus")
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyAssignedToMe", comment: "Notify when assigned to me toggle"), systemImage: "person.fill.badge.plus")
                }
                Toggle(isOn: $settings.notifyLabelsUpdated) {
                    // SwiftUI.Label("Notify when watched labels change", systemImage: "tag")
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyWatchedLabels", comment: "Notify when watched labels change toggle"), systemImage: "tag")
                }
                Toggle(isOn: $settings.notifyWithSummary) {
                    // SwiftUI.Label("Include summary notification", systemImage: "text.badge.star")
                    SwiftUI.Label(String(localized: "settings.backgroundSync.includeSummary", comment: "Include summary notification toggle"), systemImage: "text.badge.star")
                }

                if settings.notifyLabelsUpdated {
                    NavigationLink(destination: LabelWatchListView(settings: settings).environmentObject(appState)) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.purple).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                // Text("Watched Labels").font(.body)
                                Text(String(localized: "settings.backgroundSync.watchedLabels.title", comment: "Title for watched labels"))
                                // TODO: Localize
                                Text("common.selectedCount \(settings.watchedLabelIDs.count)",
                                     comment: "Number of labels selected")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary).font(.caption)
                        }
                    }
                }
                
                #if DEBUG
                // Debug section to test background sync
                // This section does not need localization
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "common.debugInfo", comment: "Debug info"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastAttempt = UserDefaults.standard.object(forKey: "lastBackgroundSyncAttempt") as? TimeInterval {
                        Text("settings.backgroundSync.lastAttempt \(Date(timeIntervalSince1970: lastAttempt).formatted())",
                              comment: "Label in Background Sync settings showing the last attempt time. Placeholder is a formatted date")

                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSuccess = UserDefaults.standard.object(forKey: "lastBackgroundSyncSuccess") as? TimeInterval {
                        Text("settings.backgroundSync.lastSuccess \(Date(timeIntervalSince1970: lastSuccess).formatted())",
                             comment: "Label in Background Sync settings showing the last successful sync time. Placeholder is a formatted date")

                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(String(localized: "settings.backgroundSync.debug.runSyncNow", comment: "Debug button to run sync now")) {
                        Task {
                            await BackgroundSyncService.shared.runSyncNowForTesting()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                #endif
            }
            // TODO: Localize
        } header: { 
            // Text("Background Sync & Notifications (Beta)")
            Text(String(localized: "settings.backgroundSync.header", comment: "Background sync settings header"))
        } footer: {
            Text(String(localized: "settings.backgroundSync.footer", comment: "iOS schedules background refresh based on system conditions. Frequency is a minimum interval."))
        }
        }


    // Helper to display notification authorization state
    private var statusText: String {
        switch notifications.authorizationStatus {
        case .notDetermined: return "Not Requested"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }    
}
