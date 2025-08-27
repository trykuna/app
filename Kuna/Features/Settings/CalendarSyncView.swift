// Features/Settings/CalendarSyncView.swift
import SwiftUI
import EventKit

struct CalendarSyncView: View {
    @StateObject private var calendarSync = CalendarSyncService.shared
    @StateObject private var engine = CalendarSyncEngine()

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false
    @State private var showOnboarding = false
    @State private var showDisableOptions = false

    var body: some View {
        NavigationView {
            List {
                enableSection
                if appSettings.calendarSyncPrefs.isEnabled {
                    configurationSection
                    statusSection
                    errorsSection
                    statisticsSection
                    
                    // ADVANCED (optional)
                    Section {
                        // Toggle("Show Technical Details", isOn: $showAdvanced.animation())
                        Toggle(String(localized: "settings.calendarSync.showTechnicalDetails", comment: "Show technical details toggle"), isOn: $showAdvanced.animation())
                    }
                    if showAdvanced {
                        technicalDetailsSection
                    }
                } else {
                    introSection
                }
            }
            // .navigationTitle("Calendar Sync")
            .navigationTitle(String(localized: "settings.calendarSync.navigationTitle", comment: "Calendar sync navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Button("Done") { dismiss() }
                    Button(String(localized: "common.done", comment: "Done button")) { dismiss() }
                }
            }
            .sheet(isPresented: $showOnboarding) {
                CalendarSyncOnboardingView()
            }
            .sheet(isPresented: $showDisableOptions) {
                DisableCalendarSyncView(engine: engine)
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

    // On iOS 17+, reading events requires Full Access (write-only cannot read)
    private var hasReadAccess: Bool {
        let status = calendarSync.authorizationStatus
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    // MARK: - View Sections
    
    @ViewBuilder
    private var enableSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Text("Calendar Sync")
                    Text(String(localized: "settings.calendarSync.title", comment: "Title for calendar sync"))
                        .font(.headline)
                    Text(appSettings.calendarSyncPrefs.isEnabled ? String(localized: "settings.calendarSync.enabled.title", comment: "Title for enabled") : String(localized: "common.disabled", comment: "Title for disabled"))
                        .font(.caption)
                        .foregroundColor(appSettings.calendarSyncPrefs.isEnabled ? .green : .secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { appSettings.calendarSyncPrefs.isEnabled },
                    set: { newValue in
                        if newValue {
                            // Turning on - show onboarding
                            showOnboarding = true
                        } else {
                            // Turning off - show disable options
                            showDisableOptions = true
                        }
                    }
                ))
                .labelsHidden()
                .disabled(engine.isSyncing)
            }
        }
    }
    
    @ViewBuilder
    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Text("Sync with Calendar")
                        Text(String(localized: "settings.calendarSync.intro.title", comment: "Title for sync with calendar"))
                            .font(.headline)
                        // Text("Keep your tasks in sync with your calendar app")
                        Text(String(localized: "settings.calendarSync.intro.subtitle", comment: "Subtitle for sync with calendar"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Button("Set up Calendar Sync") {
                Button(String(localized: "settings.calendarSync.setupButton", comment: "Set up calendar sync button")) {
                    showOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var configurationSection: some View {
        Section(String(localized: "common.configuration", comment: "Configuration")) {
            HStack {
                // Text("Mode")
                Text(String(localized: "settings.calendarSync.mode.title", comment: "Title for mode"))
                Spacer()
                Text(appSettings.calendarSyncPrefs.mode.displayName)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(String(localized: "settings.calendarSync.projects.title", comment: "Title for projects"))
                Spacer()
                // Text("common.selectedCount \(appSettings.calendarSyncPrefs.selectedProjectIDs.count)",
                //      comment: "Number of projects selected for calendar sync")
                //     .foregroundColor(.secondary)
                let count = appSettings.calendarSyncPrefs.selectedProjectIDs.count
                Text(
                String.localizedStringWithFormat(
                    NSLocalizedString("common.selectedCount",
                                    comment: "Number of projects selected for calendar sync"),
                    count   // Swift Int
                )
                )
                .foregroundColor(.secondary)
            }
            
            if appSettings.calendarSyncPrefs.mode == .single {
                if let calendar = appSettings.calendarSyncPrefs.singleCalendar {
                    HStack {
                        // Text("Calendar")
                        Text(String(localized: "settings.calendarSync.calendar.title", comment: "Title for calendar"))
                        Spacer()
                        Text(calendar.name)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    // Text("Calendars")
                    Text(String(localized: "settings.calendarSync.calendars.title", comment: "Title for calendars"))
                    Spacer()
                    // TODO: Localize
                    let count = appSettings.calendarSyncPrefs.projectCalendars.count
                    Text("\(count) calendars")
                        .foregroundColor(.secondary)
                }
            }
            
            // Button("Reconfigure") {
            Button(String(localized: "settings.calendarSync.reconfigure", comment: "Reconfigure button")) {
                showOnboarding = true
            }
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var technicalDetailsSection: some View {
        Section(String(localized: "settings.calendarSync.technicalDetails", comment: "Technical Details")) {
            DetailRow(label: "URL Scheme", value: "kuna://task/<id>")
            DetailRow(label: "Event Marker", value: "KUNA_EVENT:")
            DetailRow(label: "Mode", value: appSettings.calendarSyncPrefs.mode.rawValue)
            DetailRow(label: "Version", value: "\(appSettings.calendarSyncPrefs.version)")
        }
        .font(.caption)
    }
    
    @ViewBuilder
    private var statusSection: some View {
        // Section("Status") {
        Section(String(localized: "settings.calendarSync.status", comment: "Status section")) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.headline)

                    if let last = engine.lastSyncDate {
                        Text("settings.calendarSync.status.lastSynced \(last, style: .relative)",
                             comment: "Shows 'Last synced:' followed by a relative time (system handles 'ago' / 'in')")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("settings.calendarSync.status.neverSynced",
                             comment: "Shown in Calendar Sync settings when sync has never run")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if engine.isSyncing {
                    ProgressView().scaleEffect(0.8)
                }
            }

            // TODO: Localize
            // Button("Sync Now") {
            Button(String(localized: "settings.calendarSync.syncNow", comment: "Sync now button")) {
                Task { await engine.resyncNow() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(engine.isSyncing || !canPerformSync)
        }
    }
    
    @ViewBuilder
    private var calendarSection: some View {
        if let cal = calendarSync.selectedCalendar {
            Section(String(localized: "common.calendar", comment: "Calendar")) {
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
                    Text(cal.allowsContentModifications ? String(localized: "settings.calendarSync.writable", comment: "Writable calendar") : String(localized: "settings.calendarSync.readOnly", comment: "Read-only calendar"))
                        .font(.caption)
                        .foregroundColor(cal.allowsContentModifications ? .green : .orange)
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorsSection: some View {
        if !engine.syncErrors.isEmpty || !calendarSync.syncErrors.isEmpty {
            Section(String(localized: "settings.calendarSync.errors.title", comment: "Title for recent errors")) {
                ForEach(Array((engine.syncErrors + calendarSync.syncErrors).enumerated()), id: \.offset) { index, err in
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                // Button("Clear Errors") {
                Button(String(localized: "settings.calendarSync.clearErrors", comment: "Clear calendar sync errors button")) {
                    engine.syncErrors.removeAll()
                    calendarSync.syncErrors.removeAll()
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private var statisticsSection: some View {
        if hasReadAccess {
            Section(String(localized: "settings.calendarSync.statistics", comment: "Statistics section")) {
                statRow(icon: "calendar.badge.plus", color: .green,
                        label: "Synced Events", value: "\(syncedEventsCount)")
                statRow(icon: "xmark.circle", color: .red,
                        label: "Errors", value: "\((engine.syncErrors + calendarSync.syncErrors).count)")
            }
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
        // Require read access before attempting to fetch events (iOS 17+: Full Access)
        guard hasReadAccess else {
            return 0
        }
        guard let cal = calendarSync.selectedCalendar else {
            return 0
        }
        let pred = calendarSync.eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30*24*60*60),
            end: Date().addingTimeInterval(30*24*60*60),
            calendars: [cal]
        )
        let events = calendarSync.eventStore.events(matching: pred)
        let kunaEvents = events.filter { $0.url?.absoluteString.hasPrefix("kuna://task/") == true }
        return kunaEvents.count
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
        .environmentObject(AppSettings.shared)
}
#endif
