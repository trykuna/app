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
                        Text(String(localized: "background_sync_title", comment: "Title for background sync"))
                        // Text("Sync tasks periodically in the background")
                        Text(String(localized: "background_sync_subtitle", comment: "Subtitle for background sync"))
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
                        Text(String(localized: "background_sync_frequency_title", comment: "Title for background sync frequency"))
                        // Text("How often to refresh tasks in background")
                        Text(String(localized: "background_sync_frequency_subtitle", comment: "Subtitle for background sync frequency"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.backgroundSyncFrequency) {
                        Text(String(localized: "background_sync_frequency_15m", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_30m", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_1h", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_1h", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_6h", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_12h", comment: "Frequency for background sync"))
                        Text(String(localized: "background_sync_frequency_24h", comment: "Frequency for background sync"))
                    }.pickerStyle(.menu)
                }
                HStack {
                    Image(systemName: notifications.authorizationStatus == .authorized ? "bell.badge.fill" : "bell.badge")
                        .foregroundColor(notifications.authorizationStatus == .authorized ? .green : .orange)
                    // TODO: Localize
                    Text("Notifications: \(statusText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if notifications.authorizationStatus == .notDetermined || notifications.authorizationStatus == .denied {
                        Button("Enable") {
                            Task { _ = await notifications.requestAuthorizationIfNeeded() }
                        }
                        .buttonStyle(.bordered)
                    }
                }


                Toggle(isOn: $settings.notifyNewTasks) {
                    SwiftUI.Label("Notify on new tasks", systemImage: "bell.badge")
                }
                Toggle(isOn: $settings.notifyUpdatedTasks) {
                    SwiftUI.Label("Notify on updated tasks", systemImage: "bell")
                }
                Toggle(isOn: $settings.notifyAssignedToMe) {
                    SwiftUI.Label("Notify when assigned to me", systemImage: "person.fill.badge.plus")
                }
                Toggle(isOn: $settings.notifyLabelsUpdated) {
                    SwiftUI.Label("Notify when watched labels change", systemImage: "tag")
                }
                Toggle(isOn: $settings.notifyWithSummary) {
                    SwiftUI.Label("Include summary notification", systemImage: "text.badge.star")
                }

                if settings.notifyLabelsUpdated {
                    NavigationLink(destination: LabelWatchListView(settings: settings).environmentObject(appState)) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.purple).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                // Text("Watched Labels").font(.body)
                                Text(String(localized: "background_sync_watched_labels_title", comment: "Title for watched labels"))
                                // TODO: Localize
                                Text("\(settings.watchedLabelIDs.count) selected")
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
                    Text("Debug Info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastAttempt = UserDefaults.standard.object(forKey: "lastBackgroundSyncAttempt") as? TimeInterval {
                        Text("Last Attempt: \(Date(timeIntervalSince1970: lastAttempt).formatted())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSuccess = UserDefaults.standard.object(forKey: "lastBackgroundSyncSuccess") as? TimeInterval {
                        Text("Last Success: \(Date(timeIntervalSince1970: lastSuccess).formatted())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Run Sync Now (Debug)") {
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
        } header: { Text("Background Sync & Notifications (Beta)") } footer: {
            Text("iOS schedules background refresh based on system conditions. Frequency is a minimum interval.")
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

