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
            let allProjects = try await api.fetchProjects()
            // Filter out projects named "Favorites" to avoid confusion with the dedicated Favorites section
            projects = allProjects.filter { $0.title.lowercased() != "favorites" }

            #if DEBUG
            let filteredCount = allProjects.count - projects.count
            if filteredCount > 0 {
                print("Filtered out \(filteredCount) project(s) named 'Favorites'")
            }
            #endif

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
                NewProjectView(isPresented: $showingNewProject, api: api)
            }
        }
    }
}
