// KunaWidget/WidgetConfiguration.swift
import WidgetKit
import AppIntents
import SwiftUI
import os

// MARK: - Widget Configuration
struct ProjectSelectionConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Task Widget"
    static var description = IntentDescription("Select priority level and project to display tasks from.")
    
    @Parameter(title: "Priority Filter")
    var priorityFilter: PriorityEntity?
    
    @Parameter(title: "Project")
    var project: ProjectEntity?
    
    init() {
        self.priorityFilter = PriorityEntity.allPriorities
        self.project = ProjectEntity.allProjects
    }
}

// MARK: - Medium Widget Configuration (Project only)
struct ProjectOnlyConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Priority Breakdown Widget"
    static var description = IntentDescription("Select project to display priority breakdown from.")
    
    @Parameter(title: "Project")
    var project: ProjectEntity?
    
    init() {
        self.project = ProjectEntity.allProjects
    }
}

// MARK: - Priority Entity
struct PriorityEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priority")
    static var defaultQuery = PriorityQuery()
    
    let id: String
    let displayName: String
    let priority: WidgetTaskPriority?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
    
    // Predefined priority entities - using same names as main app
    static let allPriorities = PriorityEntity(id: "all", displayName: "All Priorities", priority: nil)
    static let unsetPriority = PriorityEntity(id: "unset", displayName: "No Priority", priority: .unset)
    static let lowPriority = PriorityEntity(id: "low", displayName: "Low", priority: .low)
    static let mediumPriority = PriorityEntity(id: "medium", displayName: "Medium", priority: .medium)
    static let highPriority = PriorityEntity(id: "high", displayName: "High", priority: .high)
    static let urgentPriority = PriorityEntity(id: "urgent", displayName: "Urgent", priority: .urgent)
    static let criticalPriority = PriorityEntity(id: "critical", displayName: "Do Now!", priority: .doNow)
}

// MARK: - Priority Query
struct PriorityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PriorityEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [PriorityEntity] {
        return [
            PriorityEntity.allPriorities,
            PriorityEntity.criticalPriority,
            PriorityEntity.urgentPriority,
            PriorityEntity.highPriority,
            PriorityEntity.mediumPriority,
            PriorityEntity.lowPriority,
            PriorityEntity.unsetPriority
        ]
    }
    
    func defaultResult() async -> PriorityEntity? {
        return PriorityEntity.allPriorities
    }
}

// MARK: - Project Entity
struct ProjectEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")
    static var defaultQuery = ProjectQuery()
    
    let id: String
    let displayName: String
    let projectId: Int?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
    
    // Default entity for all projects
    static let allProjects = ProjectEntity(id: "all", displayName: "All Projects", projectId: nil)
}

// MARK: - Project Query
struct ProjectQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [ProjectEntity] {
        Log.widget.debug("suggestedEntities() called - starting project fetch")
        // Fetch real projects from API
        do {
            let realProjects = try await fetchProjectsFromAPI()
            
            var entities = [ProjectEntity.allProjects] // Always include "All Projects"
            
            // Add REAL projects from the API
            for project in realProjects {
                let entity = ProjectEntity(
                    id: "project_\(project.id)",
                    displayName: project.title,
                    projectId: project.id
                )
                entities.append(entity)
            }
            
            return entities
        } catch {
            Log.widget.error("Failed to fetch projects: \(error)")
            // Only return All Projects if API fails - no fake data
            return [ProjectEntity.allProjects]
        }
    }
    
    private func fetchProjectsFromAPI() async throws -> [WidgetProject] {
        // Try to read from cached projects first
        Log.widget.debug("Attempting to read projects from cache...")
        if let cachedProjects = readProjectsFromCache() {
            Log.widget.info("Found \(cachedProjects.count) cached projects")
            return cachedProjects
        }
        
        Log.widget.debug("No cached projects, falling back to API...")
        
        // Fallback to API if cache is empty
        // Read keychain data with detailed logging
        Log.widget.debug("Attempting to read server URL from keychain...")
        guard let serverURLString = readWidgetServerURL() else {
            Log.widget.error("Failed to read server URL from keychain")
            throw WidgetAPIError.badURL
        }
        
        guard let serverURL = URL(string: serverURLString) else {
            Log.widget.error("Invalid server URL: \(serverURLString)")
            throw WidgetAPIError.badURL
        }
        
        Log.widget.debug("Server URL: \(serverURLString)")
        
        Log.widget.debug("Attempting to read token from keychain...")
        guard let token = readWidgetToken() else {
            Log.widget.error("Failed to read token from keychain")
            throw WidgetAPIError.missingToken
        }
        
        Log.widget.debug("Token found, length: \(token.count)")
        
        // Create API config and fetch projects
        let config = WidgetVikunjaConfig(baseURL: serverURL)
        let api = WidgetVikunjaAPI(config: config, token: token)
        
        Log.widget.debug("Fetching projects from API...")
        let projects = try await api.fetchProjects()
        Log.widget.info("Fetched \(projects.count) projects")
        
        return projects
    }
    
    private func readProjectsFromCache() -> [WidgetProject]? {
        let appGroupID = "group.tech.systemsmystery.kuna"
        let projectsKey = "shared_projects_snapshot_v1"
        
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: projectsKey) else {
            Log.widget.debug("No cached projects found")
            return nil
        }
        
        // Define a simple struct to decode the cached projects
        struct CachedProject: Codable {
            let id: Int
            let title: String
            let description: String?
        }
        
        do {
            let projects = try JSONDecoder().decode([CachedProject].self, from: data)
            return projects.map { project in
                WidgetProject(id: project.id, title: project.title, description: project.description)
            }
        } catch {
            Log.widget.error("Failed to decode cached projects: \(error)")
            return nil
        }
    }
    
    func defaultResult() async -> ProjectEntity? {
        return ProjectEntity.allProjects
    }
}
