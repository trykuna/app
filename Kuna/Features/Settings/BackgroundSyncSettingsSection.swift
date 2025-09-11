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
                        
                        Text(String(localized: "settings.backgroundSync.title", comment: "Title for background sync"))
                        
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
                        
                        Text(String(localized: "settings.backgroundSync.frequency.title",
                                    comment: "Title for background sync frequency"))
                        
                        Text(String(localized: "settings.backgroundSync.frequency.subtitle",
                                    comment: "Subtitle for background sync frequency"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.backgroundSyncFrequency) {
                        Text(
                            String(localized: "settings.backgroundSync.frequency.15m", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.30m", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.1h", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.1h", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.6h", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.12h", 
                                   comment: "Frequency for background sync")
                        )
                        Text(
                            String(localized: "settings.backgroundSync.frequency.24h", 
                                   comment: "Frequency for background sync")
                        )
                    }.pickerStyle(.menu)
                }
                HStack {
                    Image(systemName: notifications.authorizationStatus == .authorized ? "bell.badge.fill" : "bell.badge")
                        .foregroundColor(notifications.authorizationStatus == .authorized ? .green : .orange)
                    Text("settings.backgroundSync.notifications \(statusText)",
                            comment: "Placeholder is the status text (e.g. Enabled, Disabled)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if notifications.authorizationStatus == .notDetermined || notifications.authorizationStatus == .denied {
                        
                        Button(String(localized: "common.enable", comment: "Enable button")) {
                            Task { _ = await notifications.requestAuthorizationIfNeeded() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Toggle(isOn: $settings.notifyNewTasks) {
                    
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyNewTasks",
                                        comment: "Notify on new tasks toggle"), systemImage: "bell.badge")
                }
                Toggle(isOn: $settings.notifyUpdatedTasks) {
                    
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyUpdatedTasks",
                                        comment: "Notify on updated tasks toggle"), systemImage: "bell")
                }
                Toggle(isOn: $settings.notifyAssignedToMe) {
                    
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyAssignedToMe",
                                        comment: "Notify when assigned to me toggle"), systemImage: "person.fill.badge.plus")
                }
                Toggle(isOn: $settings.notifyLabelsUpdated) {
                    
                    SwiftUI.Label(String(localized: "settings.backgroundSync.notifyWatchedLabels",
                                        comment: "Notify when watched labels change toggle"), systemImage: "tag")
                }
                Toggle(isOn: $settings.notifyWithSummary) {
                    
                    SwiftUI.Label(String(localized: "settings.backgroundSync.includeSummary",
                                        comment: "Include summary notification toggle"), systemImage: "text.badge.star")
                }

                if settings.notifyLabelsUpdated {
                    NavigationLink(destination: LabelWatchListView(settings: settings).environmentObject(appState)) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.purple).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                
                                Text(String(localized: "settings.backgroundSync.watchedLabels.title",
                                                comment: "Title for watched labels"))
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
                                comment: "Background Sync last attempt time with formatted date placeholder")

                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSuccess = UserDefaults.standard.object(forKey: "lastBackgroundSyncSuccess") as? TimeInterval {
                        Text("settings.backgroundSync.lastSuccess \(Date(timeIntervalSince1970: lastSuccess).formatted())",
                                comment: "Background Sync last success time with formatted date placeholder")

                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(String(localized: "settings.backgroundSync.debug.runSyncNow",
                                    comment: "Debug button to run sync now")) {
                        Task {
                            await BackgroundSyncService.shared.runSyncNowForTesting()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                #endif
            }
        } header: { 
            
            Text(String(localized: "settings.backgroundSync.header", comment: "Background sync settings header"))
        } footer: {
            Text(String(localized: "settings.backgroundSync.footer",
                        comment: "iOS schedules background refresh based on system conditions. Frequency is a minimum interval."))
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
