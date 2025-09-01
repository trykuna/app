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
    private static let maxCachedTasks = 50 // Reasonable limit for widget display
    
    static func writeWidgetSnapshot(from tasks: [VikunjaTask], projectId: Int) {
        Log.widget.debug("Writing widget snapshot: tasks=\(tasks.count, privacy: .public) projectId=\(projectId, privacy: .public)") // swiftlint:disable:this line_length
        
        // Check if App Group is configured
        guard UserDefaults(suiteName: appGroupID) != nil else {
            Log.widget.warning("App Group '\(appGroupID)' not configured - skipping widget cache write")
            return
        }
        
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
        
        // Limit the total number of cached tasks to prevent memory issues
        if allItems.count > maxCachedTasks {
            // Keep the most recent tasks (by due date, then by ID)
            allItems = Array(allItems.sorted { (task1, task2) in
                // Sort by due date first, then by ID (most recent first)
                if task1.dueDate != task2.dueDate {
                    return task1.dueDate > task2.dueDate
                }
                return task1.id > task2.id
            }.prefix(maxCachedTasks))
            Log.widget.debug("Trimmed widget cache to \(maxCachedTasks) tasks")
        }
        
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

            // Reload widget timelines now that we have a widget target
            WidgetCenter.shared.reloadTimelines(ofKind: "KunaWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "KunaPriorityWidget")
            Log.widget.debug("Widget timelines reloaded")
            
        } catch {
            Log.widget.error("Failed to encode task snapshot: \(String(describing: error), privacy: .public)")
        }
    }
    
    static func writeProjectsSnapshot(from projects: [Project]) {
        Log.widget.debug("Writing projects snapshot: count=\(projects.count, privacy: .public)")
        #if DEBUG
        Log.widget.debug("Using App Group ID: \(appGroupID, privacy: .public) projectsKey: \(projectsKey, privacy: .public)")
        #endif
        
        // Check if App Group is configured
        guard UserDefaults(suiteName: appGroupID) != nil else {
            Log.widget.warning("App Group '\(appGroupID)' not configured - skipping projects cache write")
            return
        }
        
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
                Log.widget.debug("Available keys after write: \(Array(defaults.dictionaryRepresentation().keys), privacy: .public)") // swiftlint:disable:this line_length
                #endif
            } else {
                Log.widget.error("Failed to read back written projects data")
            }
            
        } catch {
            Log.widget.error("Main App: Failed to encode projects snapshot: \(String(describing: error), privacy: .public)")
        }
    }
    
    static func performMemoryCleanup() {
        Log.widget.debug("WidgetCacheWriter: Performing memory cleanup")
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            Log.widget.error("Failed to create UserDefaults for memory cleanup")
            return
        }
        
        // Clear old snapshot data to free memory
        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(SharedTaskSnapshot.self, from: data) {
            
            // Keep only the most recent 25 tasks for emergency memory relief
            let trimmedItems = Array(snapshot.items.sorted { (task1, task2) in
                if task1.dueDate != task2.dueDate {
                    return task1.dueDate > task2.dueDate
                }
                return task1.id > task2.id
            }.prefix(25))
            
            let trimmedSnapshot = SharedTaskSnapshot(
                generatedAt: Date(),
                items: trimmedItems
            )
            
            do {
                let trimmedData = try JSONEncoder().encode(trimmedSnapshot)
                defaults.set(trimmedData, forKey: snapshotKey)
                defaults.synchronize()
                Log.widget.debug("WidgetCacheWriter: Trimmed cache from \(snapshot.items.count) to \(trimmedItems.count) tasks")
            } catch {
                Log.widget.error("WidgetCacheWriter: Failed to encode trimmed snapshot: \(String(describing: error))")
            }
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
