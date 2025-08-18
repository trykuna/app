// Features/Settings/SettingsView.swift
import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = AppSettings.shared
    @StateObject private var iconManager = AppIconManager.shared
    @StateObject private var calendarSync = CalendarSyncService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingAppIcons = false
    @State private var showingCalendarPicker = false
    @State private var isRequestingCalendarAccess = false
    @State private var showingCalendarError = false
    @State private var calendarErrorMessage = ""

    var body: some View {
        NavigationView {
            List {
                // Privacy & Analytics
                Section(header: Text("Privacy")) {
                    Toggle(isOn: analyticsBinding) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.purple).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Anonymous Analytics").font(.body)
                                Text("Help improve the app by sending anonymous usage data")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Display
                Section {
                    NavigationLink(destination: TaskDisplayOptionsView()) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Display Options").font(.body)
                                Text("Customize what appears on task lists")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                } header: { Text("Display Options") } footer: {
                    Text("Control which elements are displayed in task lists. Changes apply to all task views.")
                }

                // Preview moved into Display Options screen to live alongside the toggles

                // Appearance
                Section {
                    Button(action: { showingAppIcons = true }) {
                        HStack {
                            AdaptiveLogo(iconManager.currentIcon.logoVariant)
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Icon").font(.body)
                                Text(iconManager.currentIcon.displayName)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary.opacity(0.6))
                                .font(.caption)
                        }
                    }
                } header: { Text("Appearance") }

                // Task List
                Section {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.orange).font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Sort Order").font(.body)
                            Text("How tasks are sorted when you open a project")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.defaultSortOption) {
                            ForEach(TaskSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: { Text("Task List") }

                // Calendar Sync
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green).font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Sync").font(.body)
                            Text("Sync tasks with your calendar app")
                                .font(.caption).foregroundColor(.secondary)
                            Text("Status: \(authorizationStatusText)")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        Spacer()
                        if isRequestingCalendarAccess {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: $settings.calendarSyncEnabled).labelsHidden()
                        }
                    }

                    if settings.calendarSyncEnabled {
                        Button(action: { showingCalendarPicker = true }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue).font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calendar").font(.body)
                                    Text(calendarSync.selectedCalendar?.title ?? "Select Calendar")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }

                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-sync New Tasks").font(.body)
                                Text("Automatically sync new tasks to calendar")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.autoSyncNewTasks).labelsHidden()
                        }

                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.purple).font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync Tasks with Dates Only").font(.body)
                                Text("Only sync tasks that have start, due, or end dates")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.syncTasksWithDatesOnly).labelsHidden()
                        }

                        // ✅ Unified Calendar Sync screen
                        NavigationLink(destination: CalendarSyncView()) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.blue).font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync Status").font(.body)
                                    Text("View sync status and resolve conflicts")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }

                        if calendarSync.authorizationStatus == .notDetermined ||
                            calendarSync.authorizationStatus == .denied {
                            Button("Request Calendar Access") {
                                isRequestingCalendarAccess = true
                                Task {
                                    let granted = await calendarSync.requestCalendarAccess()
                                    await MainActor.run {
                                        isRequestingCalendarAccess = false
                                        if !granted {
                                            if let lastError = calendarSync.syncErrors.last {
                                                calendarErrorMessage = lastError
                                                showingCalendarError = true
                                            }
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRequestingCalendarAccess)
                        }
                    }
                } header: { Text("Calendar Integration") } footer: {
                    if settings.calendarSyncEnabled {
                        Text("Tasks will be synced to your selected calendar. Calendar access permission is required.")
                    } else {
                        Text("Enable calendar sync to integrate your tasks with the Calendar app.")
                    }
                }

                BackgroundSyncSettingsSection(settings: settings)
                    .environmentObject(appState)


                // Connection
                Section {
                    HStack(spacing: 12) {
                        LeadingIcon(systemName: "server.rack", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Server").font(.body)
                            if let serverURL = Keychain.readServerURL() {
                                Text(serverURL).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            } else {
                                Text("No server configured")
                                    .font(.caption).foregroundColor(.secondary).italic()
                            }
                        }
                        Spacer()
                        StatusIcon(systemName: Keychain.readServerURL() != nil ?
                                   "checkmark.circle.fill" : "xmark.circle.fill",
                                   color: Keychain.readServerURL() != nil ? .green : .red)
                    }

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            LeadingIcon(systemName: appState.canManageUsers ? "person.2.fill" : "person.2.slash",
                                        color: appState.canManageUsers ? .blue : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("User Management").font(.body)
                                Text(appState.canManageUsers ? "Available" : "Requires username/password login")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            StatusIcon(systemName: appState.canManageUsers ?
                                       "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                       color: appState.canManageUsers ? .green : .orange)
                        }
                        if !appState.canManageUsers {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider().padding(.top, 12)
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.orange).font(.caption).padding(.top, 1)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Why is user management limited?")
                                            .font(.caption).fontWeight(.medium)
                                        Text("The Vikunja API restricts user management operations when using personal API tokens. To assign tasks to other users or manage team members, you need to log in with username and password authentication.")
                                            .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                                        Text("You can still create and manage your personal tasks with full functionality.")
                                            .font(.caption2).foregroundColor(.secondary).fontWeight(.medium).padding(.top, 2)
                                        Button(action: {
                                            appState.logout()
                                            dismiss()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.right.circle")
                                                Text("Switch to Username/Password Login")
                                            }
                                            .font(.caption).fontWeight(.medium)
                                        }
                                        .buttonStyle(.bordered).controlSize(.small).padding(.top, 6)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1)).cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }

                    HStack(spacing: 12) {
                        LeadingIcon(systemName: appState.authenticationMethod?.systemImage ?? "questionmark.circle", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Authentication Method").font(.body)
                            HStack(spacing: 4) {
                                Text(appState.authenticationMethod?.description ?? "Unknown method")
                                if let method = appState.authenticationMethod {
                                    Image(systemName: method == .personalToken ? "key.fill" : "person.fill")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        StatusIcon(systemName: appState.isAuthenticated ?
                                   "checkmark.circle.fill" : "questionmark.circle",
                                   color: appState.isAuthenticated ? .green : .secondary)
                    }

                    if appState.authenticationMethod == .usernamePassword,
                       let expirationDate = appState.tokenExpirationDate {
                        HStack(spacing: 12) {
                            LeadingIcon(systemName: "clock", color: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Token Expiration").font(.body)
                                let t = expirationDate.timeIntervalSinceNow
                                if t > 0 {
                                    Text("Expires in \(t.formattedDuration)")
                                        .font(.caption).foregroundColor(.secondary)
                                } else {
                                    Text("Token expired").font(.caption).foregroundColor(.red)
                                }
                            }
                            Spacer()
                            let t = expirationDate.timeIntervalSinceNow
                            let status: (String, Color) =
                                t > 86400 ? ("checkmark.circle.fill", .green) :
                                t > 3600  ? ("exclamationmark.triangle.fill", .orange) :
                                            ("xmark.circle.fill", .red)
                            StatusIcon(systemName: status.0, color: status.1)
                        }
                    }
                } header: { Text("Connection") }

                // Information
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue).font(.body)
                            Text("About").font(.body)
                        }
                    }
                } header: { Text("Information") }

                // Account
                Section {
                    Button("Sign Out", role: .destructive) {
                        appState.logout()
                        dismiss()
                    }
                } header: { Text("Account") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAppIcons) { AppIconView() }
            .sheet(isPresented: $showingCalendarPicker) { CalendarPickerView() }
            .onAppear { iconManager.updateCurrentIcon() }
            .onChange(of: settings.calendarSyncEnabled) { oldValue, newValue in
                if newValue && !oldValue {
                    isRequestingCalendarAccess = true
                    Task {
                        let granted = await calendarSync.requestCalendarAccess()
                        await MainActor.run {
                            isRequestingCalendarAccess = false
                            if !granted {
                                settings.calendarSyncEnabled = false
                                if let lastError = calendarSync.syncErrors.last {
                                    calendarErrorMessage = lastError
                                    showingCalendarError = true
                                }
                            }
                        }
                    }
                }
            }
            .alert("Calendar Access Required", isPresented: $showingCalendarError) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(calendarErrorMessage)
            }
        }
    }

    // MARK: - Helpers

    private var authorizationStatusText: String {
        switch calendarSync.authorizationStatus {
        case .notDetermined: return "Not Requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized (Legacy)"
        case .fullAccess: return "Full Access"
        case .writeOnly: return "Write Only"
        @unknown default: return "Unknown"
        }
    }

    // Centralized binding to simplify type checking of Toggle
    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.shared.analyticsEnabled },
            set: { newValue in
                Analytics.setEnabled(newValue)
                AppSettings.shared.analyticsConsentDecision = newValue ? AnalyticsConsent.granted.rawValue : AnalyticsConsent.denied.rawValue
                Analytics.track("analytics_consent_toggle", parameters: ["enabled": newValue ? "true" : "false"]) }
        )
    }
}

// MARK: - Consistent UI Helpers

private struct LeadingIcon: View {
    let systemName: String
    let color: Color
    var body: some View {
        Image(systemName: systemName)
            .font(.body).foregroundColor(color)
            .frame(width: 24, alignment: .leading)
    }
}

private struct StatusIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
    }
}

// MARK: - Preview Row
private struct PreviewTaskRow: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        HStack(spacing: 12) {
            // Done toggle dot (static)
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .frame(width: 20)

            // Optional color ball
            if settings.showTaskColors && settings.showDefaultColorBalls {
                Circle()
                    .fill(Color(hex: "007AFF"))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Sample task title")
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if settings.showPriorityIndicators {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Today, 12:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if settings.showAttachmentIcons {
                        Image(systemName: "paperclip")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    if settings.showCommentCounts {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}


// MARK: - Previews
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Minimal preview harness with mock AppState and sample services
        let appState = AppState()
        // Provide a placeholder API so views relying on appState.api won’t crash in preview
        appState.api = VikunjaAPI(config: .init(baseURL: URL(string: "https://preview.example.com/api/v1")!), tokenProvider: { nil })
        appState.authenticationMethod = .personalToken
        AppSettings.shared.defaultSortOption = .dueDate

        return NavigationView {
            SettingsView()
                .environmentObject(appState)
        }
        .previewDisplayName("Settings")
    }
}
