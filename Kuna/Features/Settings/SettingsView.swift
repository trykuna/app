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
    @State private var showingCalendarSync = false

    var body: some View {
        NavigationView {
            settingsList
        }
    }
    
    private var settingsList: some View {
        List {
            Group {
                privacySection
                displaySection
                appearanceSection
                taskListSection
            }
            
            Group {
                calendarIntegrationSection
                BackgroundSyncSettingsSection(settings: settings)
                    .environmentObject(appState)
            }
            
            Group {
                connectionSection
                informationSection
                accountSection
            }
        }
        .navigationTitle(String(localized: "settings.title", comment: "Title for settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "common.done", comment: "Done button")) { dismiss() }
            }
        }
        .sheet(isPresented: $showingAppIcons) { AppIconView() }
        .sheet(isPresented: $showingCalendarSync) { 
            CalendarSyncView()
                .environmentObject(appState)
                .environmentObject(settings)
        }
        .onAppear { 
            calendarSync.refreshAuthorizationStatus()
            iconManager.updateCurrentIcon()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            calendarSync.refreshAuthorizationStatus()
        }
    }

    // MARK: - View Sections
    
    @ViewBuilder
    private var privacySection: some View {
        
        Section(header: Text(String(localized: "settings.privacy.header", comment: "Privacy section header"))) {
            Toggle(isOn: analyticsBinding) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.purple).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.privacy.analytics.title",
                                    comment: "Title for anonymous analytics")).font(.body)
                        Text(String(localized: "settings.privacy.analytics.subtitle",
                                    comment: "Title for help improve the app by sending anonymous usage data"))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var displaySection: some View {
        Section {
            NavigationLink(destination: TaskDisplayOptionsView()) {
                HStack {
                    Image(systemName: "eye")
                        .foregroundColor(.blue).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.display.title",
                                    comment: "Title for display options")).font(.body)
                        Text(String(localized: "settings.display.subtitle",
                                    comment: "Title for customize what appears on task lists"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        } header: { 
            Text(String(localized: "settings.display.title", comment: "Display options settings header"))
        } footer: {
            Text(String(localized: "settings.display.footer",
                        comment: "Title for control which elements are displayed in task lists changes apply to all task views"))
        }
    }
    
    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Button(action: { showingAppIcons = true }) {
                HStack {
                    AdaptiveLogo(iconManager.currentIcon.logoVariant)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.appearance.appIcon.title", comment: "Title for app icon")).font(.body)
                        Text(iconManager.currentIcon.displayName)
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.caption)
                }
            }
            
            HStack {
                Image(systemName: "house")
                    .foregroundColor(.orange).font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.appearance.defaultView.title", comment: "Default View")).font(.body)
                    Text(String(localized: "settings.appearance.defaultView.subtitle",
                                comment: "Which view opens when you launch the app"))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Picker("", selection: $settings.defaultView) {
                    ForEach(AppSettings.DefaultView.allCases, id: \.self) { view in
                        Text(view.displayName).tag(view)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: { 
            Text(String(localized: "settings.appearance.title", comment: "Settings section header for appearance"))
        }
    }
    
    @ViewBuilder
    private var taskListSection: some View {
        Section {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.orange).font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.taskList.sortOrder.title",
                                comment: "Title for default sort order")).font(.body)
                    Text(String(localized: "settings.taskList.sortOrder.subtitle",
                                comment: "Title for how tasks are sorted when you open a project"))
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
        } header: { Text(String(localized: "tasks.list.title", comment: "Task List")) }
    }
    
    @ViewBuilder
    private var calendarIntegrationSection: some View {
        Section {
            Button(action: { showingCalendarSync = true }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.green).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            String(
                                localized: "settings.calendarSync.title",
                                comment: "Title for calendar sync"
                            )
                        )
                        .font(.body)
                        .foregroundColor(.primary)

                        Text(
                            settings.calendarSyncPrefs.isEnabled
                                ? "\(settings.calendarSyncPrefs.mode.displayName) • \(settings.calendarSyncPrefs.selectedProjectIDs.count) projects" // swiftlint:disable:this line_length
                                : String(
                                    localized: "settings.calendarSync.description",
                                    comment: "Calendar sync description"
                                )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                    HStack(spacing: 4) {
                        if settings.calendarSyncPrefs.isEnabled {
                            Text(String(localized: "settings.calendarSync.enabled.title", comment: "Title for enabled"))
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        } header: { 
            Text(String(localized: "settings.calendarSync.title", comment: "Title for calendar integration")) 
        } footer: {
            Text(String(localized: "settings.calendarSync.footer",
                        comment: "Footer explaining calendar sync safety - creates own calendars without touching existing ones"))
        }
    }
    
    @ViewBuilder
    private var connectionSection: some View {
        Section {
            HStack(spacing: 12) {
                LeadingIcon(systemName: "server.rack", color: .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.connection.server.title", comment: "Title for server")).font(.body)
                    if let serverURL = Keychain.readServerURL() {
                        Text(serverURL).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Text(String(localized: "settings.connection.server.noServer.title",
                                    comment: "Title for no server configured"))
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
                        Text(String(localized: "settings.connection.userManagement.title",
                                    comment: "Title for user management")).font(.body)
                        Text(String(localized: "settings.connection.userManagement.subtitle",
                                    comment: "Subtitle for user management"))
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
                                Text(String(localized: "settings.connection.userManagement.limited.title",
                                            comment: "Title for why is user management limited"))
                                    .font(.caption).fontWeight(.medium)
                                Text(String(localized: "settings.connection.userManagement.limited.text",
                                            comment: "Text for why is user management limited"))
                                    .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                                Text(String(localized: "settings.connection.userManagement.limited.text2",
                                            comment: "Text for why is user management limited"))
                                    .font(.caption2).foregroundColor(.secondary).fontWeight(.medium).padding(.top, 2)
                                Button(action: {
                                    appState.logout()
                                    dismiss()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right.circle")
                                        Text(String(localized:
                                                        "settings.connection.userManagement.switchToUsernamePassword.title",
                                                    comment: "Title for switch to username/password login"))
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
                    Text(String(localized: "settings.connection.authMethod.title",
                                comment: "Title for authentication method")).font(.body)
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
                            Text(String(localized: "settings.connection.tokenExpiration.title",
                                        comment: "Title for token expiration")).font(.body)
                            let t = expirationDate.timeIntervalSinceNow
                            if t > 0 {
                                Text("settings.view.token.expiresIn \(t.formattedDuration)",
                                    comment: "JWT token expiration label with formatted duration placeholder")
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text(String(localized: "settings.auth.token.expired",
                                            comment: "Token expired")).font(.caption).foregroundColor(.red)
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
        } header: { 
            Text(String(localized: "settings.connection.header", comment: "Connection settings header"))
        }
    }
    
    @ViewBuilder
    private var informationSection: some View {
        Section {
            NavigationLink(destination: AboutView()) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue).font(.body)
                    Text(String(localized: "common.about", comment: "About")).font(.body)
                }
            }
        } header: { Text(String(localized: "settings.information.header", comment: "Information section header")) }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section {
            Button(String(localized: "common.signOut", comment: "Sign Out"), role: .destructive) {
                appState.logout()
                dismiss()
            }
        } header: {
            Text(String(localized: "common.account", comment: "Account"))
        }
    }
    
    // MARK: - Helpers

    private var authorizationStatusText: String {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            switch status {
            case .notDetermined: return "Not Requested"
            case .restricted: return "Restricted"
            case .denied: return "Denied"
            case .fullAccess: return "Full Access"
            case .writeOnly: return "Write Only"
            default: return "Unknown"
            }
        } else {
            switch status {
            case .notDetermined: return "Not Requested"
            case .restricted: return "Restricted"
            case .denied: return "Denied"
            case .authorized: return "Authorized"
            default: return "Unknown"
            }
        }
    }

    // Centralized binding to simplify type checking of Toggle
    @MainActor
    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { settings.analyticsEnabled },
            set: { newValue in
                Analytics.setEnabled(newValue)
                settings.analyticsConsentDecision = newValue
                    ? AnalyticsConsent.granted.rawValue
                    : AnalyticsConsent.denied.rawValue
                Analytics.track("analytics_consent_toggle", parameters: ["enabled": newValue ? "true" : "false"]) 
            }
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
                    .fill(Color(hex: "007AFF") ?? .blue)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(String(localized: "tasks.sample.title", comment: "Title for sample task"))
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
                    Text(String(localized: "common.time.today1200", comment: "Title for today 12 00"))
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
                            Text(verbatim: "3")
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
        appState.api = VikunjaAPI(
            config: .init(
                baseURL: URL(string: "https://preview.example.com/api/v1")! // swiftlint:disable:this force_unwrapping
            ),
            tokenProvider: { nil }
        )
        appState.authenticationMethod = .personalToken
        AppSettings.shared.defaultSortOption = .dueDate

        return NavigationView {
            SettingsView()
                .environmentObject(appState)
        }
        .previewDisplayName("Settings")
    }
}
