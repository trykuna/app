//
//  SharedFileManager.swift
//  Kuna
//
//  Created by Claude on 15/08/2025.
//

import Foundation

class SharedFileManager {
    static let shared = SharedFileManager()

    private let fileManager = FileManager.default

    // Use a shared location that both iOS and watchOS simulators can access
    private var sharedDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sharedPath = documentsPath.appendingPathComponent("VikunjaShared")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: sharedPath, withIntermediateDirectories: true)

        return sharedPath
    }

    private var projectsFile: URL {
        sharedDirectory.appendingPathComponent("projects.json")
    }

    private var tasksFile: URL {
        sharedDirectory.appendingPathComponent("tasks.json")
    }

    func writeProjects(_ projects: [Project]) {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: self.projectsFile)
            Log.app.debug("iOS: Wrote projects to shared file: \(self.projectsFile.path, privacy: .public)")
        } catch {
            Log.app.error("iOS: Failed to write projects to shared file: \(String(describing: error), privacy: .public)")
        }
    }

    func readProjects() -> [Project]? {
        do {
            let data = try Data(contentsOf: self.projectsFile)
            let projects = try JSONDecoder().decode([Project].self, from: data)
            Log.watch.debug("Watch: Read \(projects.count, privacy: .public) projects from shared file")
            return projects
        } catch {
            Log.watch.error("Watch: Failed to read projects from shared file: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func writeTasks(_ tasks: [VikunjaTask], for projectId: Int) {
        // Create a simple task structure for sharing
        struct SharedTask: Codable {
            let id: Int
            let title: String
            let dueDate: Date
            let isOverdue: Bool
            let priority: String
            let projectId: Int
        }

        let sharedTasks = tasks.map { task in
            SharedTask(
                id: task.id,
                title: task.title,
                dueDate: task.dueDate ?? Date(),
                isOverdue: (task.dueDate?.timeIntervalSince1970 ?? 0) < Date().timeIntervalSince1970,
                priority: task.priority.priorityString,
                projectId: projectId
            )
        }

        do {
            // Read existing tasks from other projects
            var allTasks: [SharedTask] = []
            if let existingData = try? Data(contentsOf: self.tasksFile),
               let existingTasks = try? JSONDecoder().decode([SharedTask].self, from: existingData) {
                // Keep tasks from other projects
                allTasks = existingTasks.filter { $0.projectId != projectId }
            }

            // Add new tasks for this project
            allTasks.append(contentsOf: sharedTasks)

            let data = try JSONEncoder().encode(allTasks)
            try data.write(to: self.tasksFile)
            Log.app.debug("iOS: Wrote tasks to shared file: \(self.tasksFile.path, privacy: .public)")
        } catch {
            Log.app.error("iOS: Failed to write tasks to shared file: \(String(describing: error), privacy: .public)")
        }
    }
    // Provide a simplified tasks payload suitable for WC reply
    // Matches the watch expectation: array of dictionaries with primitive types
    func readTasks(for projectId: Int) -> [[String: Any]] {
        struct SharedTask: Codable {
            let id: Int
            let title: String
            let dueDate: Date
            let isOverdue: Bool
            let priority: String
            let projectId: Int
        }
        do {
            let data = try Data(contentsOf: self.tasksFile)
            let all = try JSONDecoder().decode([SharedTask].self, from: data)
            let filtered = all.filter { $0.projectId == projectId }
            return filtered.map { t in
                [
                    "id": t.id,
                    "title": t.title,
                    "dueDate": t.dueDate.timeIntervalSince1970,
                    "isOverdue": t.isOverdue,
                    "priority": t.priority,
                    "projectId": t.projectId
                ]
            }
        } catch {
            Log.watch.error("iOS: Failed to read tasks for WC reply: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    // This method is not needed in the iOS app - only for watchOS
    // The iOS app only writes tasks, doesn't read them

    private init() {}
}
