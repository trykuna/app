// Services/CalendarSync/CalendarSyncAPI.swift
import Foundation

// MARK: - Calendar Sync API Protocol

protocol CalendarSyncAPI {
    func fetchTasks(updatedSince: String?, listIDs: [String], window: DateInterval) async throws -> [CalendarSyncTask]
    func patchTask(_ patch: TaskPatch) async throws -> CalendarSyncTask
}

// MARK: - Calendar Sync Task Model

struct CalendarSyncTask {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let isAllDay: Bool
    let reminders: [RelativeReminder]
    let updatedAtISO8601: String
    let deleted: Bool
    
    init(from vikunjaTask: VikunjaTask) {
        self.id = String(vikunjaTask.id)
        self.title = vikunjaTask.title
        self.notes = vikunjaTask.description
        self.dueDate = vikunjaTask.dueDate
        self.isAllDay = vikunjaTask.isAllDay

        if let due = vikunjaTask.dueDate, let absRems = vikunjaTask.reminders {
            self.reminders = absRems.map { r in
                RelativeReminder(relativeSeconds: r.reminder.timeIntervalSince(due))
            }
        } else {
            self.reminders = [] // no due date → no relative reminders
        }

        self.updatedAtISO8601 = vikunjaTask.updatedAt?.iso8601 ?? Date().iso8601
        self.deleted = vikunjaTask.done
    }
}

// MARK: - VikunjaAPI Extension

extension VikunjaAPI: CalendarSyncAPI {
    func fetchTasks(updatedSince: String?, listIDs: [String], window: DateInterval) async throws -> [CalendarSyncTask] {
        // 1) If no lists selected, default to ALL projects (nicer UX).
        var projectIds = listIDs.compactMap(Int.init)
        if projectIds.isEmpty {
            let projects = try await fetchProjects()
            projectIds = projects.map { $0.id }
        }

        // 2) Compare dates as Date (avoid string/format pitfalls)
        let iso = ISO8601DateFormatter()
        let sinceDate = updatedSince.flatMap { iso.date(from: $0) }

        // 3) Fetch per project in parallel
        var all: [VikunjaTask] = []
        try await withThrowingTaskGroup(of: [VikunjaTask].self) { group in
            for pid in projectIds {
                group.addTask {
                    // NOTE: If your server paginates, you can switch to the queryItems variant
                    // and loop page=1... until count < perPage. Keeping it simple for now.
                    return try await self.fetchTasks(projectId: pid)
                }
            }
            for try await tasks in group { all += tasks }
        }

        // 4) Cursor: keep only tasks updated after `sinceDate` (if provided)
        if let since = sinceDate {
            all = all.filter { t in
                guard let u = t.updatedAt else { return true }
                return u > since
            }
        }

        // 5) Calendar only makes sense for tasks that actually have a date.
        //    Keep tasks whose due/start/end intersect the rolling window.
        let dated = all.filter { task in
            let hasDate = (task.dueDate != nil) || (task.startDate != nil) || (task.endDate != nil)
            guard hasDate else { return false }
            if let d = task.dueDate, window.contains(d) { return true }
            if let s = task.startDate, window.contains(s) { return true }
            if let e = task.endDate, window.contains(e) { return true }
            return false
        }

        return dated.map { CalendarSyncTask(from: $0) }
    }
    
    func patchTask(_ patch: TaskPatch) async throws -> CalendarSyncTask {
        guard let taskId = Int(patch.id) else {
            throw CalendarSyncError.invalidTaskId
        }
        
        // Get current task
        let currentTask = try await getTask(taskId: taskId)
        
        // Create updated task with patches applied
        var updatedTask = currentTask
        
        if let title = patch.title {
            updatedTask.title = title
        }
        
        if let notes = patch.notes {
            updatedTask.description = notes
        }
        
        if let dueDate = patch.dueDate {
            updatedTask.dueDate = patch.isAllDay == true
                ? dueDate.dateOnlyUTC   // you can add a helper that strips time components
                : dueDate
        }
        
        if let reminders = patch.reminders {
            if let dueDate = updatedTask.dueDate {
                updatedTask.reminders = reminders.map { Reminder(reminder: dueDate.addingTimeInterval($0)) }
            } else {
                updatedTask.reminders = [] // no due date = no reminders
            }
        }
        
        // Update the task via API
        let savedTask = try await updateTask(updatedTask)
        
        return CalendarSyncTask(from: savedTask)
    }
}

// MARK: - Calendar Sync Errors

enum CalendarSyncError: LocalizedError {
    case invalidTaskId
    case taskNotFound
    case syncConflict
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTaskId:
            return "Invalid task ID"
        case .taskNotFound:
            return "Task not found"
        case .syncConflict:
            return "Sync conflict detected"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
