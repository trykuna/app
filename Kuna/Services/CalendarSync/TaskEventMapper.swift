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
                let cal = Calendar.current
                let start = cal.startOfDay(for: due)
                let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24*60*60)
                event.startDate = start
                event.endDate = end
            } else {
                event.isAllDay = false
                event.endDate   = due
                event.startDate = due.addingTimeInterval(-3600) // 1h before due
            }
        } else { return }

        // Stable identity (+ project id to aid migration)
        var comps = URLComponents()
            comps.scheme = SyncConst.scheme
            comps.host = SyncConst.hostTask
            comps.path = "/\(task.id)"
            comps.queryItems = [URLQueryItem(name: "project", value: String(task.projectId))]
            event.url = comps.url

        // --- Reminders ---
        event.alarms = task.reminders.map { r in
            let offsetFromStart = event.isAllDay ? r.relativeSeconds : (r.relativeSeconds + 3600)
            return EKAlarm(relativeOffset: offsetFromStart)
        }

        // Signature stamping
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
        let existingSig = EventSignature.extractSignature(from: event.notes)
        let newSig = EventSignature.make(from: event)
        guard newSig != existingSig else { return nil }
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
              url.host == SyncConst.hostTask else { return nil }
        let _ = URLComponents(url: url, resolvingAgainstBaseURL: false)
        // path last component is the task id
        if let last = url.path.split(separator: "/").last {
            return String(last)
        }
        return url.lastPathComponent
    }

    private static func extractDueDate(from event: EKEvent) -> Date? {
        if event.isAllDay { return event.startDate?.dateOnlyUTC }
        return event.endDate
    }

    private static func extractReminders(from event: EKEvent) -> [TimeInterval]? {
        guard let alarms = event.alarms, !alarms.isEmpty else { return nil }
        return alarms.compactMap { alarm in
            event.isAllDay ? alarm.relativeOffset : (alarm.relativeOffset - 3600)
        }
    }
}

extension VikunjaTask {
    var isAllDay: Bool {
        guard let due = dueDate else { return false }
        let startOfDay = Calendar.current.startOfDay(for: due)
        return abs(due.timeIntervalSince(startOfDay)) < 60
    }
}
