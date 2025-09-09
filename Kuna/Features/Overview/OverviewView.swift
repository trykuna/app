import SwiftUI

struct OverviewView: View {
    let api: VikunjaAPI
    @Binding var isMenuOpen: Bool
    
    @State private var quickTaskTitle = ""
    @State private var isAddingTask = false
    @State private var showSuccessMessage = false
    @State private var lastCreatedTaskTitle = ""
    @State private var targetProjectName = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            if targetProjectName.isEmpty {
                                HStack {
                                    Text("Quick Add to")
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            } else {
                                Text("Quick Add to \(targetProjectName)")
                            }
                        }
                        .font(.headline)
                        HStack {
                            TextField("Add a new task", text: $quickTaskTitle)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addQuickTask()
                                }
                            
                            Button(action: addQuickTask) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(quickTaskTitle.isEmpty || isAddingTask)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Projects")
                            .font(.headline)
                        
                        if AppSettings.shared.recentProjectIds.isEmpty {
                            Text("No recent projects")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(AppSettings.shared.recentProjectIds, id: \.self) { projectId in
                                RecentProjectRow(projectId: projectId, api: api)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent tasks")
                            .font(.headline)
                        
                        if AppSettings.shared.recentTaskIds.isEmpty {
                            Text("No recent tasks")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(AppSettings.shared.recentTaskIds, id: \.self) { taskId in
                                RecentTaskRow(taskId: taskId, api: api)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                }
                .padding()
            }
            .navigationTitle(String(localized: "navigation.overview", comment: "Overview navigation title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size:18, weight: .medium))
                    }
                    .accessibilityLabel(String(localized: "navigation.menu", comment: "Menu button accessibility label"))
                }
            }
            .overlay(alignment: .top) {
                if showSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Task '\(lastCreatedTaskTitle)' added successfully!")
                            .font(.body)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                    .padding(.top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: showSuccessMessage)
                }
            }
            .onAppear {
                Task {
                    do {
                        print("🔍 Fetching user and projects...")
                        let currentUser = try await api.getCurrentUser()
                        print("👤 User ID: \(currentUser.id), Default Project ID: \(currentUser.defaultProjectId ?? -1)")
                        
                        if let defaultProjectId = currentUser.defaultProjectId {
                            let projects = try await api.fetchProjects()
                            print("📁 Found \(projects.count) projects")
                            if let project = projects.first(where: { $0.id == defaultProjectId}) {
                                await MainActor.run {
                                    targetProjectName = project.title
                                    print("✅ Set target project to: \(project.title)")
                                }
                            }
                        } else {
                            print("⚠️ No default project, using first project")
                            let projects = try await api.fetchProjects()
                            if let firstProject = projects.first {
                                await MainActor.run {
                                    targetProjectName = firstProject.title
                                    print("✅ Set target project to: \(firstProject.title)")
                                }
                            }
                        }
                    } catch {
                        print("❌ Could not get user info (likely API token), falling back to first project")
                        // Fallback for API token users - just use first project
                        do {
                            let projects = try await api.fetchProjects()
                            if let firstProject = projects.first {
                                await MainActor.run {
                                    targetProjectName = firstProject.title
                                    print("✅ Fallback: Set target project to: \(firstProject.title)")
                                }
                            }
                        } catch {
                            print("❌ Could not fetch projects: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // Function to add task
    private func addQuickTask() {
        guard !quickTaskTitle.isEmpty else { return }
        
        // Set state to true for adding task
        isAddingTask = true
        let taskTitle = quickTaskTitle
        
        Task {
            do {
                var targetProjectId: Int?
                var projectName = ""
                
                do {
                    let currentUser = try await api.getCurrentUser()
                    targetProjectId = currentUser.defaultProjectId
                    if let projectId = targetProjectId {
                        let projects = try await api.fetchProjects()
                        if let project = projects.first(where: { $0.id == projectId }) {
                            projectName = project.title
                        }
                    }
                } catch {
                    print("Could not get user's default project: \(error)")
                }
                // If no default project, use the first available project
                if targetProjectId == nil {
                    let projects = try await api.fetchProjects()
                    if let firstProject = projects.first {
                        targetProjectId = firstProject.id
                        projectName = firstProject.title
                    }
                }
                // Get all projects and select the first one if available

                guard let projectId = targetProjectId else {
                    print("No projects available")
                    await MainActor.run {
                        isAddingTask = false
                    }
                    return
                }
                
                // Update the UI with the project name
                await MainActor.run {
                    targetProjectName = projectName
                }
                
                // Create the new task
                let newTask = try await api.createTask(
                    projectId: projectId,
                    title: taskTitle,
                    description: nil
                    )
                
                // Set the status back to false after creation
                await MainActor.run {
                    lastCreatedTaskTitle = newTask.title
                    quickTaskTitle = ""
                    isAddingTask = false
                    showSuccessMessage = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccessMessage = false
                    }
                }
            } catch {
                // Set the status back to false if there is an error.
                print("Failed to create task: \(error)")
                await MainActor.run {
                    isAddingTask = false
                }
            }
        }
    }
}

struct RecentProjectRow: View {
    let projectId: Int
    let api: VikunjaAPI
    @State private var project: Project?
    
    var body: some View {
        if let project = project {
            NavigationLink(destination: TasksAdaptiveContainer(project: project, api: api)) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                    Text(project.title)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } else {
            ProgressView()
                .onAppear {
                    Task {
                        do {
                            let projects = try await api.fetchProjects()
                            if let found = projects.first(where: { $0.id == projectId }) {
                                project = found
                            }
                        } catch {
                            print("Failed to load project: \(error)")
                        }
                    }
                }
        }
    }
}

struct RecentTaskRow: View {
    let taskId: Int
    let api: VikunjaAPI
    @State private var task: VikunjaTask?
    
    var body: some View {
        if let task = task {
            NavigationLink(destination: TaskDetailView(task: task, api: api, onUpdate: nil)) {
                HStack {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.done ? .green : .secondary)
                    VStack(alignment: .leading) {
                        Text(task.title)
                            .foregroundColor(.primary)
                            .strikethrough(task.done)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } else {
            ProgressView()
                .onAppear {
                    Task {
                        do {
                            let fetchedTask = try await api.getTask(taskId: taskId)
                            task = fetchedTask
                        } catch {
                            print("Failed to load task: \(error)")
                        }
                    }
                }
        }
    }
}

#Preview {
    OverviewView(
        api: VikunjaAPI(
            config: .init(baseURL: URL(string: "https://example.com")!),
            tokenProvider: { nil }
        ),
        isMenuOpen: .constant(false)
    )
}
