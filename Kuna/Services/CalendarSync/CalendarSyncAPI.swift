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

    // Project context for per‑project calendars
    let projectId: Int
    let projectTitle: String

    init(from vikunjaTask: VikunjaTask, projectId: Int, projectTitle: String) {
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
            self.reminders = []
        }

        self.updatedAtISO8601 = vikunjaTask.updatedAt?.iso8601 ?? Date().iso8601
        self.deleted = vikunjaTask.done

        self.projectId = projectId
        self.projectTitle = projectTitle
    }
}

// MARK: - VikunjaAPI Extension

extension VikunjaAPI: CalendarSyncAPI {

    func fetchTasks(updatedSince: String?, listIDs: [String], window: DateInterval) async throws -> [CalendarSyncTask] {
        // Resolve which projects to sync (users can choose via listIDs)
        var projectIds = listIDs.compactMap(Int.init)

        let allProjects = try await fetchProjects()
        if projectIds.isEmpty {
            projectIds = allProjects.map { $0.id }
        }
        let titleById = Dictionary(uniqueKeysWithValues: allProjects.map { ($0.id, $0.title) })

        // Cursor date (optional)
        let iso = ISO8601DateFormatter()
        let sinceDate = updatedSince.flatMap { iso.date(from: $0) }

        // Fetch tasks per project in parallel
        var aggregated: [(pid: Int, title: String, tasks: [VikunjaTask])] = []
        try await withThrowingTaskGroup(of: (Int, String, [VikunjaTask]).self) { group in
            for pid in projectIds {
                let name = titleById[pid] ?? "Project \(pid)"
                group.addTask {
                    let tasks = try await self.fetchTasks(projectId: pid)
                    return (pid, name, tasks)
                }
            }
            for try await triple in group { aggregated.append(triple) }
        }

        var out: [CalendarSyncTask] = []

        for (pid, name, tasks) in aggregated {
            // Filter by cursor
            let filteredByCursor: [VikunjaTask]
            if let since = sinceDate {
                filteredByCursor = tasks.filter { t in
                    guard let u = t.updatedAt else { return true }
                    return u > since
                }
            } else {
                filteredByCursor = tasks
            }

            // Keep only tasks with any date intersecting the window
            let dated = filteredByCursor.filter { task in
                let hasDate = (task.dueDate != nil) || (task.startDate != nil) || (task.endDate != nil)
                guard hasDate else { return false }
                if let d = task.dueDate, window.contains(d) { return true }
                if let s = task.startDate, window.contains(s) { return true }
                if let e = task.endDate, window.contains(e) { return true }
                return false
            }

            out += dated.map { CalendarSyncTask(from: $0, projectId: pid, projectTitle: name) }
        }

        return out
    }

    func patchTask(_ patch: TaskPatch) async throws -> CalendarSyncTask {
        guard let taskId = Int(patch.id) else {
            throw CalendarSyncError.invalidTaskId
        }

        // Load current task, apply local edits, and save
        let currentTask = try await getTask(taskId: taskId)
        var updatedTask = currentTask

        if let title = patch.title {
            updatedTask.title = title
        }
        if let notes = patch.notes {
            updatedTask.description = notes
        }
        if let dueDate = patch.dueDate {
            updatedTask.dueDate = (patch.isAllDay == true) ? dueDate.dateOnlyUTC : dueDate
        }
        if let reminders = patch.reminders {
            if let dueDate = updatedTask.dueDate {
                updatedTask.reminders = reminders.map { Reminder(reminder: dueDate.addingTimeInterval($0)) }
            } else {
                updatedTask.reminders = []
            }
        }

        let savedTask = try await updateTask(updatedTask)

        // Resolve project context safely (projectId on task may be optional)
        let projects = try await fetchProjects()
        let parent = projects.first { $0.id == savedTask.projectId }

        let pid: Int
        let pname: String
        if let parent {
            pid = parent.id
            pname = parent.title
        } else if let projId = savedTask.projectId {
            pid = projId
            pname = "Project \(projId)"
        } else {
            pid = -1
            pname = "Unknown Project"
        }

        return CalendarSyncTask(from: savedTask, projectId: pid, projectTitle: pname)
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
        case .invalidTaskId: return "Invalid task ID"
        case .taskNotFound:  return "Task not found"
        case .syncConflict:  return "Sync conflict detected"
        case .apiError(let message): return "API error: \(message)"
        }
    }
}
