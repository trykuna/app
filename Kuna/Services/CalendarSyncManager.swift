// Services/CalendarSyncManager.swift
import Foundation
import SwiftUI
import EventKit

@MainActor
final class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()

    private let calendarSync = CalendarSyncService.shared
    private let settings = AppSettings.shared
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncConflicts: [SyncConflict] = []

    private init() {
        loadLastSyncDate()
    }

    // MARK: - Sync Coordination

    func performFullSync(api: VikunjaAPI, projectId: Int) async {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Step 1: Get all tasks for the project
            let tasks = try await api.fetchTasks(projectId: projectId)

            // Step 2: Sync tasks to calendar (one-way: tasks → calendar)
            await syncTasksToCalendar(tasks)

            // Step 3: Check for calendar changes and sync back to tasks (bidirectional)
            _ = await calendarSync.syncCalendarChangesToTasks(api: api)

            // Step 4: Handle any conflicts
            await detectAndHandleConflicts(tasks: tasks, api: api)
            // Auto-resolve conflicts by preferring the newest change
            if !syncConflicts.isEmpty {
                let conflicts = syncConflicts // snapshot; resolveConflict mutates the array
                for conflict in conflicts {
                    await resolveConflict(conflict, resolution: CalendarSyncService.SyncConflictResolution.preferNewest, api: api)
                }
            }

            // Update last sync date
            lastSyncDate = Date()
            saveLastSyncDate()

        } catch {
            calendarSync.syncErrors.append("Full sync failed: \(error.localizedDescription)")
        }
    }

    func syncTasksToCalendar(_ tasks: [VikunjaTask]) async {
        guard settings.calendarSyncEnabled else { return }

        for task in tasks {
            // Only sync tasks with dates if the setting is enabled
            if settings.syncTasksWithDatesOnly {
                let hasRequiredDates = task.startDate != nil || task.dueDate != nil || task.endDate != nil
                guard hasRequiredDates else { continue }
            }

            _ = await calendarSync.syncTaskToCalendar(task)
        }
    }

    func syncSingleTask(_ task: VikunjaTask) async -> Bool {
        guard settings.calendarSyncEnabled else { return false }

        if settings.syncTasksWithDatesOnly {
            let hasRequiredDates = task.startDate != nil || task.dueDate != nil || task.endDate != nil
            guard hasRequiredDates else { return false }
        }

        return await calendarSync.syncTaskToCalendar(task)
    }

    func removeSingleTaskFromCalendar(_ task: VikunjaTask) async -> Bool {
        return await calendarSync.removeTaskFromCalendar(task)
    }

    // MARK: - Conflict Detection and Resolution

    private func detectAndHandleConflicts(tasks: [VikunjaTask], api: VikunjaAPI) async {
        guard let calendar = calendarSync.selectedCalendar else { return }

        let predicate = calendarSync.eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            end: Date().addingTimeInterval(30 * 24 * 60 * 60),
            calendars: [calendar]
        )

        let events = calendarSync.eventStore.events(matching: predicate)
        let kunaEvents = events.filter { event in
            event.url?.absoluteString.hasPrefix("kuna://task/") == true
        }

        var newConflicts: [SyncConflict] = []

        for event in kunaEvents {
            if let taskIdString = event.url?.absoluteString.replacingOccurrences(of: "kuna://task/", with: ""),
               let taskId = Int(taskIdString),
               let task = tasks.first(where: { $0.id == taskId }) {

                // Check for conflicts between task and event
                if hasConflict(task: task, event: event) {
                    let taskModified = task.updatedAt ?? Date.distantPast
                    let eventModified = event.lastModifiedDate ?? Date.distantPast
                    let conflict = SyncConflict(
                        taskId: taskId,
                        taskTitle: task.title,
                        taskLastModified: taskModified,
                        eventLastModified: eventModified,
                        conflictType: determineConflictType(task: task, event: event)
                    )
                    newConflicts.append(conflict)
                }
            }
        }

        syncConflicts = newConflicts
    }

    private func hasConflict(task: VikunjaTask, event: EKEvent) -> Bool {
        // Check if there are meaningful differences between task and event
        if task.title != event.title { return true }
        if (task.description ?? "") != (event.notes ?? "") { return true }
        if task.startDate != event.startDate { return true }
        if task.endDate != event.endDate { return true }

        // Check reminders
        let taskReminderDates = Set(task.reminders?.map { $0.reminder } ?? [])
        let eventReminderDates = Set(event.alarms?.compactMap { $0.absoluteDate } ?? [])
        if taskReminderDates != eventReminderDates { return true }

        return false
    }

    private func determineConflictType(task: VikunjaTask, event: EKEvent) -> ConflictType {
        var conflicts: [ConflictType] = []

        if task.title != event.title { conflicts.append(.title) }
        if (task.description ?? "") != (event.notes ?? "") { conflicts.append(.description) }
        if task.startDate != event.startDate { conflicts.append(.startDate) }
        if task.endDate != event.endDate { conflicts.append(.endDate) }

        let taskReminderDates = Set(task.reminders?.map { $0.reminder } ?? [])
        let eventReminderDates = Set(event.alarms?.compactMap { $0.absoluteDate } ?? [])
        if taskReminderDates != eventReminderDates { conflicts.append(.reminders) }

        return conflicts.first ?? .title // Return the first conflict type
    }

    func resolveConflict(
        _ conflict: SyncConflict, resolution: CalendarSyncService.SyncConflictResolution, api: VikunjaAPI) async {
        guard let calendar = calendarSync.selectedCalendar else {
            syncConflicts.removeAll { $0.id == conflict.id }
            return
        }
        // Find the current task and event
        do {
            let task = try await api.getTask(taskId: conflict.taskId)

            // Find the matching event via URL scheme
            let window = DateInterval(
                start: Date().addingTimeInterval(-365*24*60*60), end: Date().addingTimeInterval(365*24*60*60))
            let predicate = calendarSync.eventStore.predicateForEvents(
                withStart: window.start, end: window.end, calendars: [calendar])
            let event = calendarSync.eventStore.events(matching: predicate).first { ev in
                ev.url?.absoluteString == "kuna://task/\(conflict.taskId)"
            }

            guard let ev = event else {
                // No matching event; nothing to resolve
                syncConflicts.removeAll { $0.id == conflict.id }
                return
            }

            // Auto-select resolution if requested
            var chosen = resolution
            if resolution == .preferNewest {
                let taskModified = task.updatedAt ?? .distantPast
                let eventModified = ev.lastModifiedDate ?? .distantPast
                chosen = (eventModified > taskModified) ? .preferCalendar : .preferTask
            }

            switch chosen {
            case .preferTask:
                // Update calendar to match task
                _ = await calendarSync.updateCalendarEvent(ev, with: task)

            case .preferCalendar:
                // Build updated task from event and push to server if changes exist
                if let updated = calendarSync.buildUpdatedTaskFromEvent(task, event: ev) {
                    do { _ = try await api.updateTask(updated) } catch {
                        calendarSync.syncErrors.append("Calendar->Task update failed: \(error.localizedDescription)")
                    }
                }

            case .manual:
                // Manual handled by UI elsewhere; nothing to do here
                break
            case .preferNewest:
                break // handled via chosen above
            }
        } catch {
            calendarSync.syncErrors.append("Conflict resolution failed: \(error.localizedDescription)")
        }

        // Remove the conflict from the list once processed
        syncConflicts.removeAll { $0.id == conflict.id }
    }

    // MARK: - Settings Persistence

    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastCalendarSyncDate") as? Date {
            lastSyncDate = timestamp
        }
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastCalendarSyncDate")
    }

    // MARK: - Utility

    func canPerformSync() -> Bool {
        return settings.calendarSyncEnabled &&
               calendarSync.authorizationStatus == .fullAccess &&
               calendarSync.selectedCalendar != nil
    }
}

// MARK: - Supporting Types

struct SyncConflict: Identifiable {
    let id = UUID()
    let taskId: Int
    let taskTitle: String
    let taskLastModified: Date
    let eventLastModified: Date
    let conflictType: ConflictType
}

enum ConflictType: String, CaseIterable {
    case title = "Title"
    case description = "Description"
    case startDate = "Start Date"
    case endDate = "End Date"
    case reminders = "Reminders"

    var systemImage: String {
        switch self {
        case .title: return "textformat"
        case .description: return "text.alignleft"
        case .startDate: return "calendar"
        case .endDate: return "calendar.badge.checkmark"
        case .reminders: return "bell"
        }
    }
}
