// Services/WidgetCacheWriter.swift
import Foundation
import WidgetKit

// MARK: - Shared Cache Types (Mirror of widget types)
struct SharedTaskSnapshot: Codable {
    struct Item: Codable {
        let id: Int
        let title: String
        let dueDate: Date
        let isOverdue: Bool
        let priority: String        // "low" | "medium" | "high" | "urgent" | "doNow" | "unset"
        let projectId: Int?
    }
    let generatedAt: Date
    let items: [Item]
}

// MARK: - Widget Cache Writer
class WidgetCacheWriter {
    private static let appGroupID = "group.tech.systemsmystery.kuna"
    private static let snapshotKey = "shared_tasks_snapshot_v1"
    private static let projectsKey = "shared_projects_snapshot_v1"
    
    static func writeWidgetSnapshot(from tasks: [VikunjaTask], projectId: Int) {
        Log.widget.debug("Writing widget snapshot: tasks=\(tasks.count, privacy: .public) projectId=\(projectId, privacy: .public)")
        
        // Read existing snapshot to preserve other projects' tasks
        var allItems: [SharedTaskSnapshot.Item] = []
        
        if let defaults = UserDefaults(suiteName: appGroupID),
           let existingData = defaults.data(forKey: snapshotKey),
           let existingSnapshot = try? JSONDecoder().decode(SharedTaskSnapshot.self, from: existingData) {
            // Keep tasks from other projects
            allItems = existingSnapshot.items.filter { $0.projectId != projectId }
            Log.widget.debug("Preserved tasks from other projects: count=\(allItems.count, privacy: .public)")
        }
        
        // Add tasks from current project
        let newItems = tasks.map { task in
            SharedTaskSnapshot.Item(
                id: task.id,
                title: task.title,
                dueDate: task.dueDate ?? Date(),
                isOverdue: {
                    guard let dueDate = task.dueDate else { return false }
                    return dueDate < Date()
                }(),
                priority: task.priority.priorityString,
                projectId: projectId
            )
        }
        
        allItems.append(contentsOf: newItems)
        Log.widget.debug("Total cached tasks after merge: \(allItems.count, privacy: .public)")
        
        let snapshot = SharedTaskSnapshot(
            generatedAt: Date(),
            items: allItems
        )
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            
            guard let defaults = UserDefaults(suiteName: appGroupID) else {
                Log.widget.error("Failed to create UserDefaults with App Group")
                return
            }
            
            defaults.set(data, forKey: snapshotKey)
            defaults.synchronize()
            
            Log.widget.debug("Successfully wrote task snapshot to App Group")

            // Reload widget timelines
            WidgetCenter.shared.reloadTimelines(ofKind: "KunaWidget")
            Log.widget.debug("Triggered widget timeline reload")
            
        } catch {
            Log.widget.error("Failed to encode task snapshot: \(String(describing: error), privacy: .public)")
        }
    }
    
    static func writeProjectsSnapshot(from projects: [Project]) {
        Log.widget.debug("Writing projects snapshot: count=\(projects.count, privacy: .public)")
        #if DEBUG
        Log.widget.debug("Using App Group ID: \(appGroupID, privacy: .public) projectsKey: \(projectsKey, privacy: .public)")
        #endif
        
        do {
            let data = try JSONEncoder().encode(projects)
            Log.widget.debug("Encoded projects data size: \(data.count, privacy: .public) bytes")
            
            guard let defaults = UserDefaults(suiteName: appGroupID) else {
                Log.widget.error("Failed to create UserDefaults with App Group")
                return
            }
            
            Log.widget.debug("Setting projects data for key: \(projectsKey, privacy: .public)")
            defaults.set(data, forKey: projectsKey)
            defaults.synchronize()

            // Verify the write
            if let readBack = defaults.data(forKey: projectsKey) {
                Log.widget.debug("Wrote projects snapshot to App Group (\(readBack.count, privacy: .public) bytes)")
                #if DEBUG
                Log.widget.debug("Available keys after write: \(Array(defaults.dictionaryRepresentation().keys), privacy: .public)")
                #endif
            } else {
                Log.widget.error("Failed to read back written projects data")
            }
            
        } catch {
            Log.widget.error("Main App: Failed to encode projects snapshot: \(String(describing: error), privacy: .public)")
        }
    }
}

// MARK: - TaskPriority Extension
extension TaskPriority {
    var priorityString: String {
        switch self {
        case .unset: return "unset"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .urgent: return "urgent"
        case .doNow: return "doNow"
        }
    }
}