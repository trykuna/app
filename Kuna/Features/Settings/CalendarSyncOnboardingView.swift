// Features/Settings/CalendarSyncOnboardingView.swift
import SwiftUI
import EventKit

struct CalendarSyncOnboardingView: View {
    @StateObject private var calendarSyncEngine = CalendarSyncEngine()
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: OnboardingStep = .intro
    @State private var selectedMode: CalendarSyncMode = .single
    @State private var selectedProjectIDs: Set<String> = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var projects: [Project] = []
    @State private var loadingProjects = false
    
    private var hasNextStep: Bool {
        switch currentStep {
        case .intro: return true
        case .modeSelection: return true
        case .projectSelection: return true
        case .confirmation: return false
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .intro: return true
        case .modeSelection: return true
        case .projectSelection: return !selectedProjectIDs.isEmpty
        case .confirmation: return true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                progressView
                
                Spacer()
                
                currentStepView
                
                Spacer()
                
                actionButtons
            }
            .padding()
            // .navigationTitle("Calendar Sync Setup")
            .navigationTitle(String(localized: "settings.calendarSync.setup.title", comment: "Calendar sync setup navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Cancel") { dismiss() }
                    Button(String(localized: "common.cancel", comment: "Cancel button")) { dismiss() }
                }
            }
            .alert(String(localized: "common.error"), isPresented: .constant(errorMessage != nil)) {
                // Button("OK") { errorMessage = nil }
                Button(String(localized: "common.ok", comment: "OK button")) { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                // Set up calendar sync engine with API and load projects
                if let api = appState.api {
                    calendarSyncEngine.setAPI(api)
                    loadProjects(api: api)
                }
            }
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                if step != OnboardingStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .intro:
            introView
        case .modeSelection:
            modeSelectionView
        case .projectSelection:
            projectSelectionView
        case .confirmation:
            confirmationView
        }
    }
    
    private var introView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                // Text("Calendar Sync")
                Text(String(localized: "settings.calendarSync.title", comment: "Title for calendar sync"))
                    .font(.title)
                    .fontWeight(.bold)
                
                // Text("Kuna creates its own calendars and never edits your existing ones.")
                Text(String(localized: "settings.calendarSync.subtitle", comment: "Subtitle for calendar sync"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "shield.checkered", title: "Safe Sync", description: "Only touches Kuna-created calendars")
                    FeatureRow(icon: "arrow.2.circlepath", title: "Two-way Sync", description: "Tasks and events stay in sync")
                    FeatureRow(icon: "folder.badge.gearshape", title: "Project Filtering", description: "Choose which projects to sync")
                }
                .padding(.top)
            }
        }
    }
    
    private var modeSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Text("Choose Sync Mode")
                Text(String(localized: "settings.calendarSync.mode.title", comment: "Title for choose sync mode"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Text("How would you like to organize your synced tasks?")
                Text(String(localized: "settings.calendarSync.mode.subtitle", comment: "Subtitle for choose sync mode"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ModeSelectionCard(
                    mode: .single,
                    isSelected: selectedMode == .single,
                    action: { selectedMode = .single }
                )
                
                ModeSelectionCard(
                    mode: .perProject,
                    isSelected: selectedMode == .perProject,
                    action: { selectedMode = .perProject }
                )
            }
        }
    }
    
    private var projectSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text(String(localized: "settings.calendarSync.projects.title", comment: "Title for select projects"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(selectedMode == .single ? 
                     String(localized: "settings.calendarSync.projectSelection.single", comment: "Choose which projects to include in your Kuna calendar") :
                     String(localized: "settings.calendarSync.projectSelection.perProject", comment: "Choose which projects to create calendars for"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Button(selectedProjectIDs.count == projects.count ? String(localized: "common.deselectAll") : String(localized: "common.selectAll")) {
                        if selectedProjectIDs.count == projects.count {
                            selectedProjectIDs.removeAll()
                        } else {
                            selectedProjectIDs = Set(projects.map { String($0.id) })
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()

                    let selected = selectedProjectIDs.count
                    let total = projects.count
                    Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString(
                        "projects.selection_status",
                        comment: "Shows how many projects are selected out of the total count"
                        ),
                        selected, total
                    )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                }
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(projects) { project in
                            ProjectSelectionRow(
                                project: project,
                                isSelected: selectedProjectIDs.contains(String(project.id)),
                                action: {
                                    let projectID = String(project.id)
                                    if selectedProjectIDs.contains(projectID) {
                                        selectedProjectIDs.remove(projectID)
                                    } else {
                                        selectedProjectIDs.insert(projectID)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Text("Confirm Setup")
                Text(String(localized: "settings.calendarSync.onboarding.title", comment: "Title for confirm setup"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Text("Review your calendar sync configuration:")
                Text(String(localized: "settings.calendarSync.onboarding.subtitle", comment: "Subtitle for confirm setup"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // TODO: Localize
            VStack(spacing: 16) {
                ConfirmationRow(
                    title: "Sync Mode",
                    value: selectedMode.displayName,
                    description: selectedMode.description
                )
                
                ConfirmationRow(
                    title: "Projects",
                    value: "\(selectedProjectIDs.count) selected",
                    description: selectedProjectsDescription
                )
                
                if selectedMode == .single {
                    ConfirmationRow(
                        title: "Calendar",
                        value: "\"Kuna\"",
                        description: "All tasks will appear in one calendar"
                    )
                } else {
                    ConfirmationRow(
                        title: "Calendars",
                        value: "\(selectedProjectIDs.count) calendars",
                        description: "One \"Kuna – ProjectName\" calendar per project"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var selectedProjectsDescription: String {
        if selectedProjectIDs.count <= 3 {
            let names = projects
                .filter { selectedProjectIDs.contains(String($0.id)) }
                .map { $0.title }
            return names.joined(separator: ", ")
        } else {
            return "Multiple projects selected"
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if currentStep != .intro {
                // Button("Back") {
                Button(String(localized: "common.back", comment: "Back button")) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .intro
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            // Button(currentStep == .confirmation ? "Enable Sync" : "Continue") {
            Button(currentStep == .confirmation ? 
                String(localized: "settings.calendarSync.enableSync", comment: "Enable sync button") : 
                String(localized: "common.continue", comment: "Continue button")) {
                if currentStep == .confirmation {
                    enableSync()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .confirmation
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed || isProcessing)
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func enableSync() {
        Task {
            await MainActor.run {
                isProcessing = true
                errorMessage = nil
            }
            
            do {
                // Set up calendar sync engine with API
                if let api = appState.api {
                    calendarSyncEngine.setAPI(api)
                }
                
                // Complete onboarding through the engine
                // The engine will handle creating and saving preferences and return the resolved prefs
                let resolvedPrefs = try await calendarSyncEngine.onboardingComplete(
                    mode: selectedMode,
                    selectedProjectIDs: selectedProjectIDs
                )
                
                // Update AppSettings directly with the resolved preferences
                await MainActor.run {
                    appSettings.calendarSyncPrefs = resolvedPrefs
                    appSettings.calendarSyncEnabled = true
                    isProcessing = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadProjects(api: VikunjaAPI) {
        guard !loadingProjects else { return }
        
        Task {
            await MainActor.run {
                loadingProjects = true
            }
            
            do {
                let fetchedProjects = try await api.fetchProjects()
                await MainActor.run {
                    projects = fetchedProjects.filter { $0.title.lowercased() != "favorites" }
                    loadingProjects = false
                }
            } catch {
                await MainActor.run {
                    loadingProjects = false
                    errorMessage = "Failed to load projects: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ModeSelectionCard: View {
    let mode: CalendarSyncMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(mode.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ProjectSelectionRow: View {
    let project: Project
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let description = project.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct ConfirmationRow: View {
    let title: String
    let value: String
    let description: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case modeSelection = 1
    case projectSelection = 2
    case confirmation = 3
}

#if DEBUG
#Preview {
    CalendarSyncOnboardingView()
        .environmentObject(AppSettings.shared)
        .environmentObject(AppState())
}
#endif
