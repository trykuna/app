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
                Section {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Default Color Balls").font(.body)
                            Text("Display color indicators for tasks using the default blue color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        Toggle("", isOn: $settings.showDefaultColorBalls).labelsHidden()
                    }
                } header: { Text("Display") } footer: {
                    Text("When disabled, only tasks with custom colors will show color balls in the task list.")
                }

                Section {
                    Button(action: { showingAppIcons = true }) {
                        HStack {
                            AdaptiveLogo(iconManager.currentIcon.logoVariant)
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Icon").font(.body).foregroundColor(.primary)
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
                
                Section {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.orange)
                            .font(.body)
                        
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

                // Calendar Sync Section
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green)
                            .font(.body)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Sync").font(.body)
                            Text("Sync tasks with your calendar app")
                                .font(.caption).foregroundColor(.secondary)

                            // Debug: Show current authorization status
                            Text("Status: \(authorizationStatusText)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

                        Spacer()

                        if isRequestingCalendarAccess {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: $settings.calendarSyncEnabled).labelsHidden()
                        }
                    }

                    if settings.calendarSyncEnabled {
                        Button(action: { showingCalendarPicker = true }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calendar").font(.body).foregroundColor(.primary)
                                    Text(calendarSync.selectedCalendar?.title ?? "Select Calendar")
                                        .font(.caption).foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .font(.caption)
                            }
                        }

                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .font(.body)

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
                                .foregroundColor(.purple)
                                .font(.body)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync Tasks with Dates Only").font(.body)
                                Text("Only sync tasks that have start, due, or end dates")
                                    .font(.caption).foregroundColor(.secondary)
                            }

                            Spacer()
                            Toggle("", isOn: $settings.syncTasksWithDatesOnly).labelsHidden()
                        }

                        NavigationLink(destination: CalendarSyncStatusView()) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.blue)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync Status").font(.body).foregroundColor(.primary)
                                    Text("View sync status and resolve conflicts")
                                        .font(.caption).foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .font(.caption)
                            }
                        }

                        // Debug: Manual access request button
                        if calendarSync.authorizationStatus == .notDetermined || calendarSync.authorizationStatus == .denied {
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

                Section {
                    // SERVER
                    HStack(alignment: .center, spacing: 12) {
                        LeadingIcon(systemName: "server.rack", color: .green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Server").font(.body)

                            if let serverURL = Keychain.readServerURL() {
                                Text(serverURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("No server configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }

                        Spacer()

                        StatusIcon(systemName: Keychain.readServerURL() != nil ? "checkmark.circle.fill" : "xmark.circle.fill",
                                   color: Keychain.readServerURL() != nil ? .green : .red)
                    }

                    // USER MANAGEMENT (aligned)
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 12) {
                            LeadingIcon(systemName: appState.canManageUsers ? "person.2.fill" : "person.2.slash",
                                        color: appState.canManageUsers ? .blue : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("User Management").font(.body)
                                Text(appState.canManageUsers ? "Available" : "Requires username/password login")
                                    .font(.caption).foregroundColor(.secondary)
                            }

                            Spacer()
                            StatusIcon(systemName: appState.canManageUsers ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                       color: appState.canManageUsers ? .green : .orange)
                        }

                        // Additional explanation when user management is not available
                        if !appState.canManageUsers {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                    .padding(.top, 12)

                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .padding(.top, 1)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Why is user management limited?")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("The Vikunja API restricts user management operations when using personal API tokens. To assign tasks to other users or manage team members, you need to log in with username and password authentication.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text("You can still create and manage your personal tasks with full functionality.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .fontWeight(.medium)
                                            .padding(.top, 2)

                                        Button(action: {
                                            appState.logout()
                                            dismiss()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.right.circle")
                                                Text("Switch to Username/Password Login")
                                            }
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .padding(.top, 6)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }

                    // AUTHENTICATION METHOD (aligned)
                    HStack(alignment: .center, spacing: 12) {
                        LeadingIcon(systemName: appState.authenticationMethod?.systemImage ?? "questionmark.circle",
                                    color: .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Authentication Method").font(.body)

                            HStack(spacing: 4) {
                                Text(appState.authenticationMethod?.description ?? "Unknown method")
                                if let method = appState.authenticationMethod {
                                    Image(systemName: method == .personalToken ? "key.fill" : "person.fill")
                                        .font(.caption)                 // match subtitle size
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.caption)                              // subtitle font
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                        StatusIcon(systemName: appState.isAuthenticated ? "checkmark.circle.fill" : "questionmark.circle",
                                   color: appState.isAuthenticated ? .green : .secondary)
                    }

                    // Token expiration info (only for username/password auth)
                    if appState.authenticationMethod == .usernamePassword,
                       let expirationDate = appState.tokenExpirationDate {
                        HStack(alignment: .center, spacing: 12) {
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
                
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.body)
                            Text("About").font(.body)
                        }
                    }
                } header: { Text("Information") }
                
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
            .sheet(isPresented: $showingCalendarPicker) {
                CalendarPickerView()
            }
            .onAppear {
                iconManager.updateCurrentIcon()
            }
            .onChange(of: settings.calendarSyncEnabled) { oldValue, newValue in
                if newValue && !oldValue {
                    isRequestingCalendarAccess = true
                    Task {
                        let granted = await calendarSync.requestCalendarAccess()
                        await MainActor.run {
                            isRequestingCalendarAccess = false
                            if !granted {
                                settings.calendarSyncEnabled = false
                                // Show error message if there are sync errors
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
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(calendarErrorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var authorizationStatusText: String {
        switch calendarSync.authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized (Legacy)"
        case .fullAccess:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
}

// Fixed-width leading icon so text columns align
private struct LeadingIcon: View {
    let systemName: String
    let color: Color
    var body: some View {
        Image(systemName: systemName)
            .font(.body)
            .foregroundColor(color)
            .frame(width: 24, alignment: .leading)   // <- consistent width
    }
}

// Consistent trailing status glyph
private struct StatusIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 24, height: 24)   // consistent frame size for alignment
            .contentShape(Rectangle())      // ensures consistent tap area
    }
}

// MARK: - Preview
#if DEBUG
extension AppState {
    static func preview(
        isAuthenticated: Bool = true,
        authMethod: AuthenticationMethod? = .personalToken,
        tokenExpiresIn seconds: TimeInterval? = nil
    ) -> AppState {
        let s = AppState()
        s.isAuthenticated = isAuthenticated
        s.authenticationMethod = authMethod
        s.tokenExpirationDate = seconds.map { Date().addingTimeInterval($0) }
        return s
    }
}

#Preview("Personal Token") {
    NavigationStack {
        SettingsView()
            .environmentObject(
                AppState.preview(isAuthenticated: true, authMethod: .personalToken)
            )
    }
}

#Preview("User/Pass (expires in 45m)") {
    NavigationStack {
        SettingsView()
            .environmentObject(
                AppState.preview(isAuthenticated: true, authMethod: .usernamePassword, tokenExpiresIn: 45 * 60)
            )
    }
}

#Preview("User/Pass (expired)") {
    NavigationStack {
        SettingsView()
            .environmentObject(
                AppState.preview(isAuthenticated: true, authMethod: .usernamePassword, tokenExpiresIn: -10)
            )
    }
}
#endif
