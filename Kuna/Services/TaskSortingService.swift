// Kuna/Services/TaskSortingService.swift
import Foundation

/// Service for sorting and grouping tasks based on different criteria
struct TaskSortingService {
    
    // MARK: - Sorting
    
    /// Sorts tasks based on the specified sort option
    static func sortTasks(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [VikunjaTask] {
        switch sortOption {
        case .serverOrder:
            return tasks // Return tasks in their original server order
        case .alphabetical:
            return tasks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .startDate:
            return tasks.sorted { task1, task2 in
                switch (task1.startDate, task2.startDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .endDate:
            return tasks.sorted { task1, task2 in
                switch (task1.endDate, task2.endDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                switch (task1.dueDate, task2.dueDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .priority:
            return tasks.sorted { $0.priority.rawValue > $1.priority.rawValue }
        }
    }
    
    // MARK: - Grouping
    
    /// Groups tasks into sections based on the specified sort option
    static func groupTasksForSorting(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [(String?, [VikunjaTask])] {
        let calendar = Calendar.current
        let now = Date()
        
        switch sortOption {
        case .serverOrder:
            return [(nil, tasks)]
        case .alphabetical:
            return [(nil, tasks)]
            
        case .startDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let startDate = task.startDate else { return "No Start Date" }
                if calendar.isDateInToday(startDate) { return "Today" }
                if calendar.isDateInTomorrow(startDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(startDate) { return "Yesterday" }
                
                let daysFromNow = calendar.dateComponents([.day], from: now, to: startDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.taskGroupingDateFormatter.string(from: startDate)
            }
            return sortGroups(grouped, for: .startDate)
            
        case .endDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let endDate = task.endDate else { return "No End Date" }
                if calendar.isDateInToday(endDate) { return "Today" }
                if calendar.isDateInTomorrow(endDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(endDate) { return "Yesterday" }
                
                let daysFromNow = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.taskGroupingDateFormatter.string(from: endDate)
            }
            return sortGroups(grouped, for: .endDate)
            
        case .dueDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let dueDate = task.dueDate else { return "No Due Date" }
                if calendar.isDateInToday(dueDate) { return "Today" }
                if calendar.isDateInTomorrow(dueDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(dueDate) { return "Yesterday" }
                
                let daysFromNow = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Overdue" }
                return DateFormatter.taskGroupingDateFormatter.string(from: dueDate)
            }
            return sortGroups(grouped, for: .dueDate)
            
        case .priority:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                return task.priority == .unset ? "No Priority" : task.priority.displayName
            }
            let priorityOrder = [TaskPriority.doNow, .urgent, .high, .medium, .low, .unset]
            return priorityOrder.compactMap { priority in
                let key = priority == .unset ? "No Priority" : priority.displayName
                if let tasks = grouped[key], !tasks.isEmpty {
                    return (key, tasks)
                }
                return nil
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private static func sortGroups(_ grouped: [String: [VikunjaTask]], for sortOption: TaskSortOption) -> [(String?, [VikunjaTask])] {
        // Define the preferred order for date-based groups
        let preferredOrder: [String]
        switch sortOption {
        case .dueDate:
            preferredOrder = ["Overdue", "Yesterday", "Today", "Tomorrow", "This Week", "This Month", "No Due Date"]
        case .startDate:
            preferredOrder = ["Past", "Yesterday", "Today", "Tomorrow", "This Week", "This Month", "No Start Date"]
        case .endDate:
            preferredOrder = ["Past", "Yesterday", "Today", "Tomorrow", "This Week", "This Month", "No End Date"]
        default:
            preferredOrder = []
        }
        
        // First add groups in preferred order
        var result: [(String?, [VikunjaTask])] = []
        for key in preferredOrder {
            if let tasks = grouped[key], !tasks.isEmpty {
                result.append((key, tasks))
            }
        }
        
        // Then add any remaining groups (specific dates) sorted alphabetically
        let remainingKeys = grouped.keys.filter { !preferredOrder.contains($0) }.sorted()
        for key in remainingKeys {
            if let tasks = grouped[key], !tasks.isEmpty {
                result.append((key, tasks))
            }
        }
        
        return result
    }
}

// Extension for DateFormatter
private extension DateFormatter {
    static let taskGroupingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}