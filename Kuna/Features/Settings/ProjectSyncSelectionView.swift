// Features/Settings/ProjectSyncSelectionView.swift
import SwiftUI

// MARK: - Color Extension for Projects
extension Color {
    static func projectColor(for id: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint, .teal]
        let index = abs(id) % colors.count
        return colors[index]
    }
}

struct ProjectSyncSelectionView: View {
    @StateObject private var settings = AppSettings.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                // Sync All Toggle
                Section {
                    Toggle(isOn: $settings.syncAllProjects) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundColor(.blue)
                                .font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                // Text("Sync All Projects")
                                Text(String(localized: "sync_all_projects_title", comment: "Title for sync all projects"))
                                    .font(.body)
                                // Text("Automatically include all current and future projects")
                                Text(String(localized: "sync_all_projects_subtitle", comment: "Subtitle for sync all projects"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    // Text("Sync Options")
                    Text(String(localized: "sync_options_title", comment: "Title for sync options"))
                } footer: {
                    if settings.syncAllProjects {
                        // Text("All projects will be synced to your calendar.")
                        Text(String(localized: "all_projects_will_be_synced_to_your_calendar_title", comment: "Title for all projects will be synced to your calendar"))
                    } else {
                        // Text("Select specific projects below to sync to your calendar.")
                        Text(String(localized: "select_specific_projects_below_to_sync_to_your_calendar_title", comment: "Title for select specific projects below to sync to your calendar"))
                    }
                }
                
                // Project Selection
                if !settings.syncAllProjects {
                    Section {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        } else if let error = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("Retry") {
                                    loadProjects()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(projects, id: \.id) { project in
                                ProjectSyncRow(
                                    project: project,
                                    isSelected: settings.selectedProjectsForSync.contains(String(project.id))
                                ) {
                                    toggleProjectSelection(project)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            // Text("Select Projects")
                            Text(String(localized: "select_projects_title", comment: "Title for select projects"))
                            Spacer()
                            if !isLoading && !projects.isEmpty {
                                // TODO: Localize
                                Text("\(settings.selectedProjectsForSync.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } footer: {
                        if !settings.selectedProjectsForSync.isEmpty {
                            // Text("Tasks from selected projects will appear in your calendar.")
                            Text(String(localized: "tasks_from_selected_projects_will_appear_in_your_calendar_title", comment: "Title for tasks from selected projects will appear in your calendar"))
                        }
                    }
                }
            }
            .navigationTitle("Project Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadProjects()
            }
        }
    }
    
    private func loadProjects() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let api = appState.api else {
                    await MainActor.run {
                        self.errorMessage = "Not connected to server"
                        self.isLoading = false
                    }
                    return
                }
                
                let fetchedProjects = try await api.fetchProjects()
                
                await MainActor.run {
                    self.projects = fetchedProjects.sorted { $0.title < $1.title }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleProjectSelection(_ project: Project) {
        let projectIdString = String(project.id)
        if settings.selectedProjectsForSync.contains(projectIdString) {
            settings.selectedProjectsForSync.remove(projectIdString)
        } else {
            settings.selectedProjectsForSync.insert(projectIdString)
        }
    }
}

// MARK: - Row View

struct ProjectSyncRow: View {
    let project: Project
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Project color indicator - using a hash of the project ID for consistent colors
                Circle()
                    .fill(Color.projectColor(for: project.id))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    ProjectSyncSelectionView()
        .environmentObject(AppState())
}
#endif