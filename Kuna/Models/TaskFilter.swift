// Models/TaskFilter.swift
import Foundation
import SwiftUI

struct TaskFilter: Codable, Equatable {
    var showCompleted: Bool = true
    var showIncomplete: Bool = true

    // Priority filter
    var filterByPriority: Bool = false
    var minPriority: TaskPriority = .unset
    var maxPriority: TaskPriority = .doNow

    // Progress filter
    var filterByProgress: Bool = false
    var minProgress: Double = 0.0
    var maxProgress: Double = 1.0

    // Date filters
    var filterByDueDate: Bool = false
    var dueDateFrom: Date?
    var dueDateTo: Date?

    var filterByStartDate: Bool = false
    var startDateFrom: Date?
    var startDateTo: Date?

    var filterByEndDate: Bool = false
    var endDateFrom: Date?
    var endDateTo: Date?

    // Labels filter
    var filterByLabels: Bool = false
    var requiredLabelIds: Set<Int> = []
    var excludedLabelIds: Set<Int> = []

    // Quick filters
    var quickFilter: QuickFilterType = .all

    enum QuickFilterType: String, CaseIterable, Codable {
        case all = "All Tasks"
        case today = "Due Today"
        case thisWeek = "Due This Week"
        case overdue = "Overdue"
        case highPriority = "High Priority"
        case inProgress = "In Progress"
        case noDate = "No Due Date"
        case completed = "Completed"
        case incomplete = "Incomplete"

        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .today: return "calendar.day.timeline.left"
            case .thisWeek: return "calendar"
            case .overdue: return "exclamationmark.triangle"
            case .highPriority: return "flag.fill"
            case .inProgress: return "progress.indicator"
            case .noDate: return "calendar.badge.minus"
            case .completed: return "checkmark.circle.fill"
            case .incomplete: return "circle"
            }
        }
    }

    // Filter application
    func apply(to tasks: [VikunjaTask]) -> [VikunjaTask] {
        var filtered = tasks

        // Apply quick filter first if not "all"
        if quickFilter != .all {
            filtered = applyQuickFilter(quickFilter, to: filtered)
        }

        // Completion status
        if !showCompleted {
            filtered = filtered.filter { !$0.done }
        }
        if !showIncomplete {
            filtered = filtered.filter { $0.done }
        }

        // Priority
        if filterByPriority {
            filtered = filtered.filter { task in
                task.priority.rawValue >= minPriority.rawValue &&
                task.priority.rawValue <= maxPriority.rawValue
            }
        }

        // Progress
        if filterByProgress {
            filtered = filtered.filter { task in
                task.percentDone >= minProgress &&
                task.percentDone <= maxProgress
            }
        }

        // Due date
        if filterByDueDate {
            filtered = filtered.filter { task in
                guard let dueDate = task.dueDate else { return false }
                if let from = dueDateFrom, dueDate < from { return false }
                if let to = dueDateTo, dueDate > to { return false }
                return true
            }
        }

        // Start date
        if filterByStartDate {
            filtered = filtered.filter { task in
                guard let startDate = task.startDate else { return false }
                if let from = startDateFrom, startDate < from { return false }
                if let to = startDateTo, startDate > to { return false }
                return true
            }
        }

        // End date
        if filterByEndDate {
            filtered = filtered.filter { task in
                guard let endDate = task.endDate else { return false }
                if let from = endDateFrom, endDate < from { return false }
                if let to = endDateTo, endDate > to { return false }
                return true
            }
        }

        // Labels
        if filterByLabels {
            filtered = filtered.filter { task in
                let taskLabelIds = Set(task.labels?.map { $0.id } ?? [])

                // Check required labels (task must have all)
                if !requiredLabelIds.isEmpty {
                    if !requiredLabelIds.isSubset(of: taskLabelIds) {
                        return false
                    }
                }

                // Check excluded labels (task must have none)
                if !excludedLabelIds.isEmpty {
                    if !excludedLabelIds.isDisjoint(with: taskLabelIds) {
                        return false
                    }
                }

                return true
            }
        }

        return filtered
    }

    private func applyQuickFilter(_ filter: QuickFilterType, to tasks: [VikunjaTask]) -> [VikunjaTask] {
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: todayStart)!

        switch filter {
        case .all:
            return tasks

        case .today:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= todayStart && dueDate < todayEnd
            }

        case .thisWeek:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= todayStart && dueDate < weekEnd
            }

        case .overdue:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < now && !task.done
            }

        case .highPriority:
            return tasks.filter { task in
                task.priority.rawValue >= TaskPriority.high.rawValue
            }

        case .inProgress:
            return tasks.filter { task in
                !task.done && task.percentDone > 0 && task.percentDone < 1
            }

        case .noDate:
            return tasks.filter { task in
                task.dueDate == nil
            }

        case .completed:
            return tasks.filter { $0.done }

        case .incomplete:
            return tasks.filter { !$0.done }
        }
    }

    var hasActiveFilters: Bool {
        quickFilter != .all ||
        !showCompleted || !showIncomplete ||
        filterByPriority || filterByProgress ||
        filterByDueDate || filterByStartDate || filterByEndDate ||
        filterByLabels
    }

    mutating func reset() {
        self = TaskFilter()
    }

    // Convert current filter settings into URL query items for server-side filtering
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        let iso = ISO8601DateFormatter()

        // Completion state
        if showCompleted && !showIncomplete {
            items.append(URLQueryItem(name: "done", value: "true"))
        } else if !showCompleted && showIncomplete {
            items.append(URLQueryItem(name: "done", value: "false"))
        }

        // Priority
        if filterByPriority {
            if minPriority != .unset {
                items.append(URLQueryItem(name: "priority_gte", value: String(minPriority.rawValue)))
            }
            items.append(URLQueryItem(name: "priority_lte", value: String(maxPriority.rawValue)))
        }

        // Progress
        if filterByProgress {
            items.append(URLQueryItem(name: "percent_done_gte", value: String(minProgress)))
            items.append(URLQueryItem(name: "percent_done_lte", value: String(maxProgress)))
        }

        // Due date windows
        if filterByDueDate {
            if let from = dueDateFrom { items.append(URLQueryItem(name: "due_date_from", value: iso.string(from: from))) }
            if let to = dueDateTo { items.append(URLQueryItem(name: "due_date_to", value: iso.string(from: to))) }
        }

        // Start date windows
        if filterByStartDate {
            if let from = startDateFrom { items.append(URLQueryItem(name: "start_date_from", value: iso.string(from: from))) }
            if let to = startDateTo { items.append(URLQueryItem(name: "start_date_to", value: iso.string(from: to))) }
        }

        // End date windows
        if filterByEndDate {
            if let from = endDateFrom { items.append(URLQueryItem(name: "end_date_from", value: iso.string(from: from))) }
            if let to = endDateTo { items.append(URLQueryItem(name: "end_date_to", value: iso.string(from: to))) }
        }

        // Labels
        if filterByLabels {
            if !requiredLabelIds.isEmpty {
                // Repeat query item to send multiple ids: labels=1&labels=2
                for id in requiredLabelIds.sorted() {
                    items.append(URLQueryItem(name: "labels", value: String(id)))
                }
            }
            if !excludedLabelIds.isEmpty {
                for id in excludedLabelIds.sorted() {
                    items.append(URLQueryItem(name: "exclude_labels", value: String(id)))
                }
            }
        }

        // Quick filter hints mapped server-side when possible
        switch quickFilter {
        case .today:
            items.append(URLQueryItem(name: "quick", value: "today"))
        case .thisWeek:
            items.append(URLQueryItem(name: "quick", value: "week"))
        case .overdue:
            items.append(URLQueryItem(name: "quick", value: "overdue"))
        case .highPriority:
            items.append(URLQueryItem(name: "priority_gte", value: String(TaskPriority.high.rawValue)))
        case .inProgress:
            items.append(URLQueryItem(name: "percent_done_between", value: "0,1"))
        case .noDate:
            items.append(URLQueryItem(name: "no_due_date", value: "true"))
        case .completed:
            items.append(URLQueryItem(name: "done", value: "true"))
        case .incomplete:
            items.append(URLQueryItem(name: "done", value: "false"))
        case .all:
            break
        }

        return items
    }

}

enum TaskSortOption: String, CaseIterable, Codable {
    case serverOrder = "Server Order"
    case alphabetical = "A-Z"
    case startDate = "Start Date"
    case endDate = "End Date"
    case dueDate = "Due Date"
    case priority = "Priority"

    var systemImage: String {
        switch self {
        case .serverOrder: return "server.rack"
        case .alphabetical: return "textformat"
        case .startDate: return "calendar.badge.clock"
        case .endDate: return "calendar.badge.checkmark"
        case .dueDate: return "calendar.badge.exclamationmark"
        case .priority: return "flag.fill"
        }
    }

    var needsSectionHeaders: Bool {
        return self != .alphabetical && self != .serverOrder
    }
}

extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}