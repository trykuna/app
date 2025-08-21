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
                statusSection
                calendarSection
                errorsSection
                statisticsSection

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
                // Hand API to the engine
                if let api = appState.api {
                    engine.setAPI(api)
                }
                // Refresh permission status in case it changed in Settings
                calendarSync.refreshAuthorizationStatus()
            }
        }
    }

    // MARK: - Status

    private var canPerformSync: Bool {
        let status = calendarSync.authorizationStatus
        if #available(iOS 17.0, *) {
            return status == .fullAccess || status == .writeOnly
        } else {
            return status == .authorized || status == .fullAccess || status == .writeOnly
        }
    }

    // MARK: - View Sections
    
    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.headline)

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
    }
    
    @ViewBuilder
    private var calendarSection: some View {
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
    }
    
    @ViewBuilder
    private var errorsSection: some View {
        if !engine.syncErrors.isEmpty || !calendarSync.syncErrors.isEmpty {
            Section("Errors") {
                ForEach(Array((engine.syncErrors + calendarSync.syncErrors).enumerated()), id: \.offset) { index, err in
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Button("Clear Errors") {
                    engine.syncErrors.removeAll()
                    calendarSync.syncErrors.removeAll()
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private var statisticsSection: some View {
        Section("Statistics") {
            statRow(icon: "calendar.badge.plus", color: .green,
                    label: "Synced Events", value: "\(syncedEventsCount)")
            statRow(icon: "xmark.circle", color: .red,
                    label: "Errors", value: "\((engine.syncErrors + calendarSync.syncErrors).count)")
        }
    }
    
    private var statusIcon: String {
        if engine.isSyncing { return "arrow.triangle.2.circlepath" }
        if !(engine.syncErrors.isEmpty && calendarSync.syncErrors.isEmpty) { return "xmark.circle" }

        switch calendarSync.authorizationStatus {
        case .notDetermined: return "questionmark.circle"
        case .denied, .restricted: return "exclamationmark.triangle"
        case .writeOnly: return "pencil.circle"
        case .authorized, .fullAccess: return "checkmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        if engine.isSyncing { return .blue }
        if !(engine.syncErrors.isEmpty && calendarSync.syncErrors.isEmpty) { return .red }

        switch calendarSync.authorizationStatus {
        case .notDetermined: return .orange
        case .denied, .restricted: return .orange
        case .writeOnly: return .orange
        case .authorized, .fullAccess: return .green
        @unknown default: return .orange
        }
    }

    private var statusText: String {
        if engine.isSyncing { return "Syncing..." }
        if !(engine.syncErrors.isEmpty && calendarSync.syncErrors.isEmpty) { return "Errors" }

        switch calendarSync.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .writeOnly:     return "Write‑only (needs full access)"
        case .authorized, .fullAccess:
            return "Ready"
        @unknown default:
            return "Unknown permission state"
        }
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
