// Features/Projects/ProjectListView.swift
import SwiftUI

@MainActor
final class ProjectListVM: ObservableObject {
    @Published var projects: [Project] = []
    @Published var loading = false
    @Published var error: String?
    private let api: VikunjaAPI
    init(api: VikunjaAPI) { self.api = api }

    func load() async {
        loading = true; defer { loading = false }
        do { 
            projects = try await api.fetchProjects()
            // Cache projects for widget configuration
            WidgetCacheWriter.writeProjectsSnapshot(from: projects)
            // Persist projects to App Group for widgets
            SharedFileManager.shared.writeProjects(projects)
        }
        catch { self.error = error.localizedDescription }
    }
    
    func createProject(title: String, description: String? = nil) async {
        loading = true; defer { loading = false }
        do { 
            let newProject = try await api.createProject(title: title, description: description)
            projects.append(newProject)
            error = nil
            // Update cached projects after creating new project
            WidgetCacheWriter.writeProjectsSnapshot(from: projects)
        }
        catch { self.error = error.localizedDescription }
    }
}

struct ProjectListView: View {
    let api: VikunjaAPI
    @EnvironmentObject var app: AppState
    @StateObject private var vm: ProjectListVM
    @State private var showingSettings = false
    @State private var showingNewProject = false

    init(api: VikunjaAPI) {
        self.api = api
        _vm = StateObject(wrappedValue: ProjectListVM(api: api))
    }

    var body: some View {
        NavigationStack {
            List(vm.projects) { p in
                NavigationLink(p.title) { TaskListView(project: p, api: api) }
            }
            .navigationTitle("Projects")
            .toolbar { 
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingNewProject = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .overlay { 
                if vm.loading { 
                    ProgressView("Loading…") 
                } else if let error = vm.error {
                    VStack {
                        Text("Error loading projects")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await vm.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .task { await vm.load() }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(app)
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectView(vm: vm, isPresented: $showingNewProject)
            }
        }
    }
}

struct NewProjectView: View {
    @ObservedObject var vm: ProjectListVM
    @Binding var isPresented: Bool
    @State private var projectTitle = ""
    @State private var projectDescription = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Project Name", text: $projectTitle)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description (Optional)", text: $projectDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Project Details")
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
        .overlay {
            if isCreating {
                ProgressView("Creating...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
    }
    
    private func createProject() {
        isCreating = true
        Task {
            await vm.createProject(
                title: projectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isCreating = false
            if vm.error == nil {
                isPresented = false
            }
        }
    }
}
