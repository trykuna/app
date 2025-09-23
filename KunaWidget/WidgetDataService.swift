// KunaWidget/WidgetDataService.swift
import Foundation
import WidgetKit
import os

@MainActor
class WidgetDataService {
    static let shared = WidgetDataService()
    private init() {}
    
    func getTodaysTasks() async -> [WidgetTask] {
        return await getTasks(projectId: nil, priorityFilter: nil, showTodayOnly: true, showOverdue: true)
    }
    
    func getTasks(
        projectId: Int?,
        priorityFilter: WidgetTaskPriority?,
        showTodayOnly: Bool,
        showOverdue: Bool
    ) async -> [WidgetTask] {
        // Fetch REAL data from API only
        do {
            let realTasks = try await fetchTasksFromAPI(projectId: projectId)
            var filteredTasks = realTasks
            
            // Filter by priority if specified
            if let priorityFilter = priorityFilter {
                filteredTasks = filteredTasks.filter { $0.priority == priorityFilter }
            }
            
            // Don't filter by date for widgets - show all tasks matching the criteria
            // Users can use the configuration to control filtering
            
            return filteredTasks.map { convertTask($0) }
        } catch {
            Log.widget.error("Data fetch error: \(error)")
            // Return empty array - NO FAKE DATA
            return []
        }
    }
    
    // MARK: - Real API Implementation
    
    private func fetchTasksFromAPI(projectId: Int?) async throws -> [WidgetVikunjaTask] {
        guard let serverURLString = readWidgetServerURL(),
              let serverURL = URL(string: serverURLString) else {
            throw WidgetAPIError.badURL
        }
        
        guard let token = readWidgetToken() else {
            throw WidgetAPIError.missingToken
        }
        
        // Create API config
        let config = WidgetVikunjaConfig(baseURL: serverURL)
        let api = WidgetVikunjaAPI(config: config, token: token)
        
        if let projectId = projectId {
            // Fetch tasks for specific project
            return try await api.fetchTasks(projectId: projectId)
        } else {
            // Fetch all projects and their tasks
            let projects = try await api.fetchProjects()
            var allTasks: [WidgetVikunjaTask] = []
            
            for project in projects {
                do {
                    let projectTasks = try await api.fetchTasks(projectId: project.id)
                    allTasks.append(contentsOf: projectTasks)
                } catch {
                    Log.widget.error("Failed to fetch tasks for project \(project.id): \(error)")
                    // Continue with other projects
                }
            }
            
            return allTasks
        }
    }
    
    private func convertTask(_ task: WidgetVikunjaTask) -> WidgetTask {
        return WidgetTask(
            id: task.id,
            title: task.title,
            dueDate: task.dueDate ?? Date(),
            isOverdue: {
                guard let dueDate = task.dueDate else { return false }
                return dueDate < Date()
            }(),
            priority: task.priority
        )
    }
}
