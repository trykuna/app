import Foundation

enum SyncConst {
    static let calendarTitle = "Kuna"
    static let calendarPerProjectPrefix = "Kuna: "          // For per-project mode
    static let perProjectSoftCap = 25                       // warn at this many calendars

    static let syncWindowBack: TimeInterval = 60*60*24*56   // 8 weeks
    static let syncWindowForward: TimeInterval = 60*60*24*365 // 12 months
    static let pushWindowBack: TimeInterval = 60*60*24*183   // 6 months
    static let pushWindowForward: TimeInterval = 60*60*24*183

    static let signatureMarker = "\n\n— KunaSig:"
    static let scheme = "kuna"        // event.url: kuna://task/<id>?project=<pid>
    static let hostTask = "task"
}

// MARK: - Data Models

struct CalendarSyncState: Codable {
    var remoteCursorISO8601: String? // last Vikunja updated_at processed
    var lastLocalScanAt: Date?       // last EKEventStore scan time

    init() {
        self.remoteCursorISO8601 = nil
        self.lastLocalScanAt = nil
    }
}

struct IdMap: Codable {
    // Stable mapping; eventIdentifier can change, so also store URL marker
    var taskIdToEventId: [String: String]   // taskID -> EKEvent.eventIdentifier
    var eventIdToTaskId: [String: String]   // EKEvent.eventIdentifier -> taskID

    init() {
        self.taskIdToEventId = [:]
        self.eventIdToTaskId = [:]
    }

    mutating func addMapping(taskId: String, eventId: String) {
        if let oldEventId = taskIdToEventId[taskId] {
            eventIdToTaskId.removeValue(forKey: oldEventId)
        }
        if let oldTaskId = eventIdToTaskId[eventId] {
            taskIdToEventId.removeValue(forKey: oldTaskId)
        }
        taskIdToEventId[taskId] = eventId
        eventIdToTaskId[eventId] = taskId
    }

    mutating func removeMapping(taskId: String) {
        if let eventId = taskIdToEventId[taskId] {
            taskIdToEventId.removeValue(forKey: taskId)
            eventIdToTaskId.removeValue(forKey: eventId)
        }
    }

    mutating func removeMapping(eventId: String) {
        if let taskId = eventIdToTaskId[eventId] {
            eventIdToTaskId.removeValue(forKey: eventId)
            taskIdToEventId.removeValue(forKey: taskId)
        }
    }
}

// Track per‑project calendars
struct ProjectCalendarMap: Codable {
    var projectIdToCalendarId: [Int: String] = [:]

    mutating func set(projectId: Int, calendarId: String) {
        projectIdToCalendarId[projectId] = calendarId
    }
    func calendarId(for projectId: Int) -> String? {
        projectIdToCalendarId[projectId]
    }
    mutating func remove(projectId: Int) {
        projectIdToCalendarId.removeValue(forKey: projectId)
    }
    var count: Int { projectIdToCalendarId.count }
}

// MARK: - Task Patch Model

struct TaskPatch {
    let id: String
    var title: String?
    var notes: String?
    var dueDate: Date?
    var isAllDay: Bool?
    var reminders: [TimeInterval]?
}

// MARK: - Relative Reminder

struct RelativeReminder: Codable {
    let relativeSeconds: TimeInterval // seconds before due date
    init(relativeSeconds: TimeInterval) {
        self.relativeSeconds = relativeSeconds
    }
}

// MARK: - Sync Mode

enum SyncMode {
    case pullOnly
    case twoWay
}

// MARK: - Window Helpers

extension SyncConst {
    static func rollingWindow(now: Date = Date()) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-syncWindowBack),
                     end: now.addingTimeInterval(syncWindowForward))
    }

    static func pushWindow(now: Date = Date()) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-pushWindowBack),
                     end: now.addingTimeInterval(pushWindowForward))
    }
}

// MARK: - String Extensions

extension String {
    func trimmedWithoutSignature() -> String {
        guard let range = range(of: SyncConst.signatureMarker) else { return self }
        return String(prefix(upTo: range.lowerBound)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date Extensions

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
    
    var startOfDayLocal: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var startOfDayUTC: Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: self)
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? self
    }
    
    var dateOnlyUTC: Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - Helper Functions

func maxISO8601(_ date1: String?, _ date2: String?) -> String? {
    guard let date1 = date1, let date2 = date2 else {
        return date1 ?? date2
    }
    return date1 > date2 ? date1 : date2
}

func appendSignature(to notes: String?, sig: String) -> String {
    let base = (notes ?? "").trimmedWithoutSignature()
    return base + SyncConst.signatureMarker + sig
}
