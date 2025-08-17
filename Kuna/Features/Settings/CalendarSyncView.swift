// Features/Settings/CalendarSyncView.swift
import SwiftUI
import EventKit

struct CalendarSyncView: View {
    @StateObject private var calendarSync = CalendarSyncService.shared
    @StateObject private var engine = CalendarSyncEngine()

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false

    var body: some View {
        NavigationView {
            List {
                // STATUS
                Section("Status") {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusText).font(.headline)

                            if let last = engine.lastSyncDate {
                                Text("Last synced: \(last, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if engine.isSyncing {
                            ProgressView().scaleEffect(0.8)
                        }
                    }

                    Button("Sync Now") {
                        Task { await engine.syncNow(mode: .twoWay) }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(engine.isSyncing || !canPerformSync)
                }

                // CALENDAR
                if let cal = calendarSync.selectedCalendar {
                    Section("Calendar") {
                        HStack {
                            Circle()
                                .fill(Color(cal.cgColor))
                                .frame(width: 14, height: 14)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cal.title).font(.body)
                                Text(cal.source.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Text(cal.allowsContentModifications ? "Writable" : "Read-only")
                                .font(.caption)
                                .foregroundColor(cal.allowsContentModifications ? .green : .orange)
                        }
                    }
                }

                // ERRORS
                if !engine.syncErrors.isEmpty {
                    Section("Errors") {
                        ForEach(engine.syncErrors, id: \.self) { err in
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        Button("Clear Errors") {
                            engine.clearErrors()
                        }
                        .foregroundColor(.blue)
                    }
                }

                // STATS (local calendar scan only)
                Section("Statistics") {
                    statRow(icon: "calendar.badge.plus", color: .green,
                            label: "Synced Events", value: "\(syncedEventsCount)")
                    statRow(icon: "xmark.circle", color: .red,
                            label: "Errors", value: "\(engine.syncErrors.count)")
                }

                // ADVANCED (optional)
                Section {
                    Toggle("Show Technical Details", isOn: $showAdvanced.animation())
                }
                if showAdvanced {
                    Section("Technical Details") {
                        DetailRow(label: "Calendar Name", value: SyncConst.calendarTitle)
                        DetailRow(label: "URL Scheme", value: "\(SyncConst.scheme)://\(SyncConst.hostTask)/<id>")
                        DetailRow(label: "Signature Marker", value: SyncConst.signatureMarker)
                        DetailRow(label: "Pull Window", value: "8w back / 12m fwd")
                        DetailRow(label: "Push Window", value: "6m back / 6m fwd")
                        DetailRow(label: "Mode", value: "Two-way (on-demand)")
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Inject API into the engine once the view appears
                if let api = appState.api as? CalendarSyncAPI {
                    engine.setAPI(api)
                }
            }
        }
    }

    // MARK: - Status

    private var canPerformSync: Bool {
        calendarSync.authorizationStatus == .fullAccess ||
        calendarSync.authorizationStatus == .authorized ||
        calendarSync.authorizationStatus == .writeOnly
    }

    private var statusIcon: String {
        if engine.isSyncing { return "arrow.triangle.2.circlepath" }
        return engine.syncErrors.isEmpty ? "checkmark.circle" : "xmark.circle"
    }

    private var statusColor: Color {
        if engine.isSyncing { return .blue }
        return engine.syncErrors.isEmpty ? .green : .red
    }

    private var statusText: String {
        if engine.isSyncing { return "Syncing..." }
        return engine.syncErrors.isEmpty ? "Ready" : "Errors"
    }

    // MARK: - Stats helpers

    private var syncedEventsCount: Int {
        guard let cal = calendarSync.selectedCalendar else { return 0 }
        let pred = calendarSync.eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30*24*60*60),
            end: Date().addingTimeInterval(30*24*60*60),
            calendars: [cal]
        )
        return calendarSync.eventStore.events(matching: pred)
            .filter { $0.url?.absoluteString.hasPrefix("kuna://task/") == true }
            .count
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

// MARK: - Small detail row view

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label + ":").foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(.primary)
        }
    }
}

#if DEBUG
#Preview {
    CalendarSyncView()
        .environmentObject(AppState())
}
#endif
