// Services/CalendarSync/TaskEventMapper.swift
import Foundation
import EventKit

struct TaskEventMapper {
    
    // MARK: - Task to Event Mapping
    
    static func apply(task: CalendarSyncTask, to event: EKEvent) {
        event.title = task.title

        // --- Dates ---
        if let due = task.dueDate {
            if task.isAllDay {
                event.isAllDay = true
                let start = due.startOfDayLocal
                event.startDate = start
                event.endDate   = start.addingTimeInterval(24*60*60) // FIX: full-day span
            } else {
                event.isAllDay = false
                event.endDate   = due
                event.startDate = due.addingTimeInterval(-3600)      // 1h block ending at due
            }
        } else {
            // No due date: skip (we now filter these out earlier anyway)
            return
        }

        // Stable identity
        event.url = URL(string: "kuna://task/\(task.id)")

        // --- Reminders ---
        event.alarms = task.reminders.map { r in
            let offsetFromDue = r.relativeSeconds
            let offsetFromStart = event.isAllDay
                ? offsetFromDue            // all-day: start == due midnight
                : offsetFromDue + 3600     // timed: start = due - 1h
            return EKAlarm(relativeOffset: offsetFromStart)
        }

        // Signature stamping (leave your existing code here)
        let sig = EventSignature.make(
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            alarms: event.alarms,
            notes: task.notes
        )
        event.notes = appendSignature(to: task.notes, sig: sig)
    }
    
    // MARK: - Event to Task Patch Extraction
    
    static func extractCalendarEdits(from event: EKEvent) -> TaskPatch? {
        guard let taskId = extractTaskId(from: event) else { return nil }
        
        // Get existing signature from notes
        let existingSig = EventSignature.extractSignature(from: event.notes)
        
        // Compute new signature from current event state
        let newSig = EventSignature.make(from: event)
        
        // If signatures match, this is our own write - ignore
        guard newSig != existingSig else { return nil }
        
        // Extract edits
        return TaskPatch(
            id: taskId,
            title: event.title,
            notes: event.notes?.trimmedWithoutSignature(),
            dueDate: extractDueDate(from: event),
            isAllDay: event.isAllDay,
            reminders: extractReminders(from: event)
        )
    }
    
    // MARK: - Helper Methods
    
    private static func extractTaskId(from event: EKEvent) -> String? {
        guard let url = event.url,
              url.scheme == SyncConst.scheme,
              url.host == SyncConst.hostTask else {
            return nil
        }
        return url.lastPathComponent
    }
    
    private static func extractDueDate(from event: EKEvent) -> Date? {
        if event.isAllDay {
            // For all-day events, use start date as due date
            return event.startDate?.dateOnlyUTC
        } else {
            // For timed events, use end date as due date (following our 1h policy)
            return event.endDate
        }
    }
    
    private static func extractReminders(from event: EKEvent) -> [TimeInterval]? {
        guard let alarms = event.alarms, !alarms.isEmpty else { return nil }
        return alarms.compactMap { alarm in
            event.isAllDay ? alarm.relativeOffset : (alarm.relativeOffset - 3600)
        }
    }
}

// MARK: - VikunjaTask Extension

extension VikunjaTask {
    var isAllDay: Bool {
        // Determine if this should be an all-day event
        // This could be based on a task property or inferred from the due date
        // For now, assume all-day if due date is at start of day
        guard let due = dueDate else { return false }
        let startOfDay = Calendar.current.startOfDay(for: due)
        return abs(due.timeIntervalSince(startOfDay)) < 60 // Within 1 minute of start of day
    }
}
