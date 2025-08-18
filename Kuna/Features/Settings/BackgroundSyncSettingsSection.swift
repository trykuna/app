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
                        Text("Background Sync").font(.body)
                        Text("Sync tasks periodically in the background")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            if settings.backgroundSyncEnabled {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frequency").font(.body)
                        Text("How often to refresh tasks in background")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.backgroundSyncFrequency) {
                        #if DEBUG
                        Text("30 sec").tag(BackgroundSyncService.Frequency.s30)
                        Text("1 min").tag(BackgroundSyncService.Frequency.m1)
                        #endif
                        Text("15 min").tag(BackgroundSyncService.Frequency.m15)
                        Text("30 min").tag(BackgroundSyncService.Frequency.m30)
                        Text("1 hour").tag(BackgroundSyncService.Frequency.h1)
                        Text("6 hours").tag(BackgroundSyncService.Frequency.h6)
                        Text("12 hours").tag(BackgroundSyncService.Frequency.h12)
                        Text("24 hours").tag(BackgroundSyncService.Frequency.h24)
                    }.pickerStyle(.menu)
                }
                HStack {
                    Image(systemName: notifications.authorizationStatus == .authorized ? "bell.badge.fill" : "bell.badge")
                        .foregroundColor(notifications.authorizationStatus == .authorized ? .green : .orange)
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
                                Text("Watched Labels").font(.body)
                                Text("\(settings.watchedLabelIDs.count) selected")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary).font(.caption)
                        }
                    }
                }
            }
        } header: { Text("Background Sync & Notifications") } footer: {
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

