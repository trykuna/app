// Models/VikunjaModels.swift
import Foundation

// Simple HTML helper
extension String {
    // Removes <p> and </p> that some APIs wrap around plain text.
    // 1) If the whole string is a single <p>...</p>, unwrap it.
    // 2) Otherwise, strip any occurrences of the tags and trim.
    func strippingWrappedParagraphTags() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<p>") && trimmed.hasSuffix("</p>") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 3)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -4)
            let inner = String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            return inner
        }
        let replaced = trimmed.replacingOccurrences(of: "<p>", with: "").replacingOccurrences(of: "</p>", with: "")
        return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import SwiftUI

struct AuthResponse: Decodable {
    let token: String
}

struct VikunjaUser: Identifiable, Codable {
    let id: Int
    let username: String
    let name: String?
    let email: String?
    let avatarProvider: String?
    let avatarFileId: Int?
    let created: Date?
    let updated: Date?

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return username
    }

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, created, updated
        case avatarProvider = "avatar_provider"
        case avatarFileId = "avatar_file_id"
    }

    // Custom decoder to handle dates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatarProvider = try container.decodeIfPresent(String.self, forKey: .avatarProvider)
        avatarFileId = try container.decodeIfPresent(Int.self, forKey: .avatarFileId)

        // Handle dates
        let formatter = ISO8601DateFormatter()
        if let createdString = try container.decodeIfPresent(String.self, forKey: .created) {
            created = formatter.date(from: createdString)
        } else {
            created = nil
        }

        if let updatedString = try container.decodeIfPresent(String.self, forKey: .updated) {
            updated = formatter.date(from: updatedString)
        } else {
            updated = nil
        }
    }

    // Manual initializer for testing/previews
    init(id: Int, username: String, name: String? = nil, email: String? = nil) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
        self.avatarProvider = nil
        self.avatarFileId = nil
        self.created = nil
        self.updated = nil
    }
}

struct Project: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey { case id, title, description }

    // Strip <p>...</p> wrappers which some backends include in descriptions
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        if let raw = try c.decodeIfPresent(String.self, forKey: .description) {
            let cleaned = raw.strippingWrappedParagraphTags()
            description = cleaned.isEmpty ? nil : cleaned
        } else {
            description = nil
        }
    }
}

struct Reminder: Identifiable, Decodable, Encodable {
    let id: Int?
    var reminder: Date

    enum CodingKeys: String, CodingKey {
        case id, reminder
    }

    // Custom decoder to handle date
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)

        // Handle reminder date
        if let reminderString = try container.decodeIfPresent(String.self, forKey: .reminder) {
            let formatter = ISO8601DateFormatter()
            reminder = formatter.date(from: reminderString) ?? Date()
        } else {
            reminder = Date()
        }
    }

    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)

        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: reminder), forKey: .reminder)
    }

    // Convenience initializer for creating new reminders
    init(reminder: Date) {
        self.id = nil
        self.reminder = reminder
    }
}

enum RepeatMode: Int, CaseIterable, Identifiable {
    case afterAmount = 0    // Repeats after the amount specified in repeat_after
    case monthly = 1        // Repeats all dates each month (ignoring repeat_after)
    case fromCurrentDate = 2 // Repeats from current date rather than last set date

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .afterAmount: return "After Specified Time"
        case .monthly: return "Monthly"
        case .fromCurrentDate: return "From Current Date"
        }
    }

    var description: String {
        switch self {
        case .afterAmount: return "Repeats after the time period you specify"
        case .monthly: return "Repeats all dates each month"
        case .fromCurrentDate: return "Repeats from the current completion date"
        }
    }

    var systemImage: String {
        switch self {
        case .afterAmount: return "clock.arrow.circlepath"
        case .monthly: return "calendar.badge.clock"
        case .fromCurrentDate: return "arrow.clockwise"
        }
    }
}

struct Label: Identifiable, Decodable, Encodable {
    let id: Int
    let title: String
    let hexColor: String?
    let description: String?

    var color: Color {
        Color(hex: hexColor ?? "007AFF") ?? .blue // Default to blue
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case hexColor = "hex_color"
        // Additional fields from API response (decode only)
        case createdBy = "created_by"
        case created, updated
    }

    // Custom decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        if let rawDesc = try container.decodeIfPresent(String.self, forKey: .description) {
            let cleaned = rawDesc.strippingWrappedParagraphTags()
            description = cleaned.isEmpty ? nil : cleaned
        } else {
            description = nil
        }

        // Handle hex_color more carefully - it might be missing or null
        if let colorString = try container.decodeIfPresent(String.self, forKey: .hexColor),
           !colorString.isEmpty {
            hexColor = colorString
        } else {
            hexColor = nil
        }
    }

    // Manual initializer for creating labels programmatically (e.g., in previews)
    init(id: Int, title: String, hexColor: String? = nil, description: String? = nil) {
        self.id = id
        self.title = title
        self.hexColor = hexColor
        self.description = description
    }

    // Custom encoder - only encode the fields we care about
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(hexColor, forKey: .hexColor)
    }
}

enum TaskPriority: Int, CaseIterable, Identifiable, Codable {
    case unset = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    case doNow = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .unset: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .doNow: return "Do Now!"
        }
    }

    var color: Color {
        switch self {
        case .unset: return .gray
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        case .doNow: return .purple
        }
    }

    var systemImage: String {
        switch self {
        case .unset: return "minus"
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        case .doNow: return "exclamationmark.2"
        }
    }
}

struct VikunjaTask: Identifiable, Decodable, Encodable {
    let id: Int
    var title: String
    var description: String?
    var done: Bool
    var dueDate: Date?
    var startDate: Date?
    var endDate: Date?
    var labels: [Label]?
    var reminders: [Reminder]?
    var priority: TaskPriority
    var percentDone: Double // Progress as percentage (0.0 to 1.0)
    var hexColor: String? // Task color as hex string
    var repeatAfter: Int? // Repeat interval in seconds
    var repeatMode: RepeatMode // How the task repeats
    var assignees: [VikunjaUser]? // Users assigned to this task
    var createdBy: VikunjaUser? // User who created the task
    var isFavorite: Bool // Whether this task is favorited by the current user
    var projectId: Int? // The ID of the project this task belongs to
    var updatedAt: Date? // When the task was last updated (for sync)
    var attachments: [TaskAttachment]? // Attachments for this task
    var commentCount: Int? // Number of comments on this task
    var relations: [TaskRelation]? // Relations to other tasks (from GET /tasks/{id})

    var color: Color {
        Color(hex: hexColor ?? "007AFF") ?? .blue // Default to blue if no color set
    }

    var hasCustomColor: Bool {
        hexColor != nil
    }

    var hasAttachments: Bool {
        guard let attachments = attachments else { return false }
        return !attachments.isEmpty
    }

    var hasComments: Bool {
        guard let commentCount = commentCount else { return false }
        return commentCount > 0
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, done, labels, reminders, priority, assignees, attachments
        case dueDate = "due_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case percentDone = "percent_done"
        case hexColor = "hex_color"
        case repeatAfter = "repeat_after"
        case repeatMode = "repeat_mode"
        case createdBy = "created_by"
        case isFavorite = "is_favorite"
        case projectId = "project_id"
        case updatedAt = "updated_at"
        case commentCount = "comment_count"
        case relations
        case relatedTasks = "related_tasks"
    }

    // Custom decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        if let rawDesc = try container.decodeIfPresent(String.self, forKey: .description) {
            let cleaned = rawDesc.strippingWrappedParagraphTags()
            description = cleaned.isEmpty ? nil : cleaned
        } else {
            description = nil
        }
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false

        // Handle dates more carefully - Vikunja uses "0001-01-01T00:00:00Z" for "no date"
        let formatter = ISO8601DateFormatter()

        // Due date
        if let dueDateString = try container.decodeIfPresent(String.self, forKey: .dueDate),
           !dueDateString.isEmpty,
           !dueDateString.hasPrefix("0001-01-01") {
            dueDate = formatter.date(from: dueDateString)
        } else {
            dueDate = nil
        }

        // Start date
        if let startDateString = try container.decodeIfPresent(String.self, forKey: .startDate),
           !startDateString.isEmpty,
           !startDateString.hasPrefix("0001-01-01") {
            startDate = formatter.date(from: startDateString)
        } else {
            startDate = nil
        }

        // End date
        if let endDateString = try container.decodeIfPresent(String.self, forKey: .endDate),
           !endDateString.isEmpty,
           !endDateString.hasPrefix("0001-01-01") {
            endDate = formatter.date(from: endDateString)
        } else {
            endDate = nil
        }

        labels = try container.decodeIfPresent([Label].self, forKey: .labels)
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders)

        // Handle priority - default to unset if missing
        let priorityValue = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        priority = TaskPriority(rawValue: priorityValue) ?? .unset

        // Handle progress - default to 0.0 if missing, ensure it's between 0.0 and 1.0
        let progressValue = try container.decodeIfPresent(Double.self, forKey: .percentDone) ?? 0.0
        percentDone = max(0.0, min(1.0, progressValue))

        // Handle repeat settings
        repeatAfter = try container.decodeIfPresent(Int.self, forKey: .repeatAfter)
        let repeatModeValue = try container.decodeIfPresent(Int.self, forKey: .repeatMode) ?? 0
        repeatMode = RepeatMode(rawValue: repeatModeValue) ?? .afterAmount

        // Handle color - can be missing or null
        if let colorString = try container.decodeIfPresent(String.self, forKey: .hexColor),
           !colorString.isEmpty {
            hexColor = colorString
        } else {
            hexColor = nil
        }

        // Handle assignees and created by
        assignees = try container.decodeIfPresent([VikunjaUser].self, forKey: .assignees)
        createdBy = try container.decodeIfPresent(VikunjaUser.self, forKey: .createdBy)

        // Handle project ID
        projectId = try container.decodeIfPresent(Int.self, forKey: .projectId)

        // Handle favorite status
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        // Handle updated at timestamp
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        // Handle attachments
        attachments = try container.decodeIfPresent([TaskAttachment].self, forKey: .attachments)

        // Handle comment count
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)

        // Handle relations (flatten grouped related_tasks map)
        if let groups = try container.decodeIfPresent([String: [VikunjaTask]].self, forKey: .relatedTasks) {
            var all: [TaskRelation] = []
            for (kindKey, tasks) in groups {
                let kind = TaskRelationKind(rawValue: kindKey.lowercased()) ?? .unknown
                for t in tasks {
                    all.append(TaskRelation(kind: kind, otherTaskId: t.id, otherTask: t))
                }
            }
            relations = all.isEmpty ? nil : all
        } else {
            relations = nil
        }

        #if DEBUG
        let idVal = id
        let titleVal = title
        let projectIdVal = projectId

        if let favoriteValue = try? container.decodeIfPresent(Bool.self, forKey: .isFavorite) {
            Log.app.debug("Decoded isFavorite for task id=\(idVal, privacy: .public) title=\(titleVal, privacy: .public): \(favoriteValue, privacy: .public)") // swiftlint:disable:this line_length
        } else {
            Log.app.debug("Task id=\(idVal, privacy: .public) title=\(titleVal, privacy: .public) has no isFavorite field, defaulting to false") // swiftlint:disable:this line_length
        }

        if let projectIdValue = projectIdVal {
            Log.app.debug("Task id=\(idVal, privacy: .public) title=\(titleVal, privacy: .public) belongs to project ID: \(projectIdValue, privacy: .public)") // swiftlint:disable:this line_length
        } else {
            Log.app.debug("Task id=\(idVal, privacy: .public) title=\(titleVal, privacy: .public) has no project ID")
        }
        #endif
    }

    init(
        id: Int,
        title: String,
        description: String? = nil,
        done: Bool = false,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        labels: [Label]? = nil,
        reminders: [Reminder]? = nil,
        priority: TaskPriority = .unset,
        percentDone: Double = 0.0,
        hexColor: String? = nil,
        repeatAfter: Int? = nil,
        repeatMode: RepeatMode = .afterAmount,
        assignees: [VikunjaUser]? = nil,
        createdBy: VikunjaUser? = nil,
        projectId: Int? = nil,
        isFavorite: Bool = false,
        attachments: [TaskAttachment]? = nil,
        commentCount: Int? = nil,
        updatedAt: Date? = nil,
        relations: [TaskRelation]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.done = done
        self.dueDate = dueDate
        self.startDate = startDate
        self.endDate = endDate
        self.labels = labels
        self.reminders = reminders
        self.priority = priority
        self.percentDone = percentDone
        self.hexColor = hexColor
        self.repeatAfter = repeatAfter
        self.repeatMode = repeatMode
        self.assignees = assignees
        self.createdBy = createdBy
        self.projectId = projectId
        self.isFavorite = isFavorite

        // new bits
        self.attachments = attachments
        self.commentCount = commentCount
        self.updatedAt = updatedAt
        self.relations = relations
    }

    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(done, forKey: .done)
        try container.encode(priority.rawValue, forKey: .priority)
        try container.encode(percentDone, forKey: .percentDone)
        try container.encodeIfPresent(hexColor, forKey: .hexColor)
        try container.encodeIfPresent(repeatAfter, forKey: .repeatAfter)
        try container.encode(repeatMode.rawValue, forKey: .repeatMode)

        // Handle date encoding
        let formatter = ISO8601DateFormatter()

        // Always encode dates - use "0001-01-01T00:00:00Z" for nil dates to clear them
        if let dueDate = dueDate {
            try container.encode(formatter.string(from: dueDate), forKey: .dueDate)
        } else {
            try container.encode("0001-01-01T00:00:00Z", forKey: .dueDate)
        }

        if let startDate = startDate {
            try container.encode(formatter.string(from: startDate), forKey: .startDate)
        } else {
            try container.encode("0001-01-01T00:00:00Z", forKey: .startDate)
        }

        if let endDate = endDate {
            try container.encode(formatter.string(from: endDate), forKey: .endDate)
        } else {
            try container.encode("0001-01-01T00:00:00Z", forKey: .endDate)
        }

        try container.encodeIfPresent(labels, forKey: .labels)
        try container.encodeIfPresent(reminders, forKey: .reminders)
        try container.encodeIfPresent(assignees, forKey: .assignees)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encode(isFavorite, forKey: .isFavorite)
        // Note: attachments are read-only from API, not encoded when updating tasks
    }
}

// Make tasks usable as navigation values / selections.
extension VikunjaTask: Hashable {
    static func == (lhs: VikunjaTask, rhs: VikunjaTask) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TasksResponse {
    let tasks: [VikunjaTask]
    let hasMore: Bool
    let currentPage: Int
    let totalPages: Int?
    let totalCount: Int?

    init(tasks: [VikunjaTask], hasMore: Bool, currentPage: Int, totalPages: Int? = nil, totalCount: Int? = nil) {
        self.tasks = tasks
        self.hasMore = hasMore
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalCount = totalCount
    }
}

struct TaskComment: Identifiable, Decodable {
    let id: Int
    let comment: String
    let author: VikunjaUser
    let created: Date
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, comment, author, created, updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let rawComment = try container.decode(String.self, forKey: .comment)
        comment = rawComment.strippingWrappedParagraphTags()
        author = try container.decode(VikunjaUser.self, forKey: .author)

        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()

        if let createdString = try? container.decode(String.self, forKey: .created),
           let createdDate = dateFormatter.date(from: createdString) {
            created = createdDate
        } else {
            created = Date()
        }

        if let updatedString = try? container.decode(String.self, forKey: .updated),
           let updatedDate = dateFormatter.date(from: updatedString) {
            updated = updatedDate
        } else {
            updated = nil
        }
    }
}

struct TaskAttachment: Identifiable, Decodable {
    let id: Int
    let fileName: String

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case file
    }

    struct FileInfo: Decodable {
        let fileName: String?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case fileName = "file_name"
            case name
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)

        if let direct = try container.decodeIfPresent(String.self, forKey: .fileName) {
            fileName = direct
        } else if let file = try container.decodeIfPresent(FileInfo.self, forKey: .file) {
            fileName = file.fileName ?? file.name ?? ""
        } else {
            fileName = ""
        }
    }
}

// MARK: - Task Relations
enum TaskRelationKind: String, CaseIterable, Codable, Identifiable {
    case unknown
    case subtask
    case parenttask
    case related
    case duplicateof
    case duplicates
    case blocking
    case blocked
    case precedes
    case follows
    case copiedfrom
    case copiedto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subtask: return "Subtask"
        case .parenttask: return "Parent Task"
        case .related: return "Related"
        case .duplicateof: return "Duplicate Of"
        case .duplicates: return "Duplicates"
        case .blocking: return "Blocking"
        case .blocked: return "Blocked By"
        case .precedes: return "Precedes"
        case .follows: return "Follows"
        case .copiedfrom: return "Copied From"
        case .copiedto: return "Copied To"
        case .unknown: return "Unknown"
        }
    }

    // Be robust to unknown/synonym values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?.lowercased() ?? "unknown"
        switch raw {
        case "subtask", "child", "childtask": self = .subtask
        case "parenttask", "parent": self = .parenttask
        case "related": self = .related
        case "duplicateof", "duplicate_of", "duplicate-of": self = .duplicateof
        case "duplicates": self = .duplicates
        case "blocking", "blocks": self = .blocking
        case "blocked", "is_blocked_by": self = .blocked
        case "precedes", "before": self = .precedes
        case "follows", "after": self = .follows
        case "copiedfrom", "copied_from": self = .copiedfrom
        case "copiedto", "copied_to": self = .copiedto
        default: self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

struct TaskRelation: Identifiable, Decodable {
    // No explicit id in API; synthesize from kind+otherTaskId
    var id: String { "\(relationKind.rawValue)#\(otherTaskId)" }
    let relationKind: TaskRelationKind
    let otherTaskId: Int
    let otherTask: VikunjaTask?

    enum CodingKeys: String, CodingKey {
        case relationKind = "relation_kind"
        case otherTaskId = "other_task_id"
        case otherTask = "other_task"
        case kind // alternative key some servers might use
        case otherTaskIdCamel = "otherTaskId"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Try multiple keys for kind
        if let k = try? c.decode(TaskRelationKind.self, forKey: .relationKind) {
            relationKind = k
        } else if let k = try? c.decode(TaskRelationKind.self, forKey: .kind) {
            relationKind = k
        } else {
            relationKind = .unknown
        }
        // Try multiple keys for id
        if let id = try? c.decode(Int.self, forKey: .otherTaskId) {
            otherTaskId = id
        } else if let id = try? c.decode(Int.self, forKey: .otherTaskIdCamel) {
            otherTaskId = id
        } else {
            // As a last resort, try to decode nested other_task.id
            if let nested = try? c.decodeIfPresent(VikunjaTask.self, forKey: .otherTask) {
                otherTaskId = nested.id
                otherTask = nested
                return
            }
            otherTaskId = -1
        }
        otherTask = try? c.decodeIfPresent(VikunjaTask.self, forKey: .otherTask)
    }
}

// Convenience init for grouped related_tasks -> relations
extension TaskRelation {
    init(kind: TaskRelationKind, otherTaskId: Int, otherTask: VikunjaTask?) {
        self.relationKind = kind
        self.otherTaskId = otherTaskId
        self.otherTask = otherTask
    }
}

// MARK: - Calendar Sync Models
enum CalendarSyncMode: String, Codable, CaseIterable {
    case single = "single"
    case perProject = "perProject"
    
    var displayName: String {
        switch self {
        case .single: return "Single Calendar"
        case .perProject: return "Calendar per Project"
        }
    }
    
    var description: String {
        switch self {
        case .single: return "All tasks in one \"Kuna\" calendar"
        case .perProject: return "Separate calendar for each project"
        }
    }
}

struct KunaCalendarRef: Codable, Hashable {
    var name: String
    var identifier: String
    
    init(name: String, identifier: String) {
        self.name = name
        self.identifier = identifier
    }
}

struct CalendarSyncPrefs: Codable, Equatable {
    var isEnabled: Bool
    var mode: CalendarSyncMode
    var selectedProjectIDs: Set<String>
    var singleCalendar: KunaCalendarRef?
    var projectCalendars: [String: KunaCalendarRef]
    var version: Int
    
    init(
        isEnabled: Bool = false,
        mode: CalendarSyncMode = .single,
        selectedProjectIDs: Set<String> = [],
        singleCalendar: KunaCalendarRef? = nil,
        projectCalendars: [String: KunaCalendarRef] = [:],
        version: Int = 1
    ) {
        self.isEnabled = isEnabled
        self.mode = mode
        self.selectedProjectIDs = selectedProjectIDs
        self.singleCalendar = singleCalendar
        self.projectCalendars = projectCalendars
        self.version = version
    }
    
    var isValid: Bool {
        switch mode {
        case .single:
            return singleCalendar != nil
        case .perProject:
            return !selectedProjectIDs.isEmpty && 
                   selectedProjectIDs.allSatisfy { projectCalendars.keys.contains($0) }
        }
    }
}

enum DisableDisposition: CaseIterable, CustomStringConvertible {
    case keepEverything
    case removeKunaEvents
    case archiveCalendars
    case deleteEverything
    
    var displayName: String {
        switch self {
        case .keepEverything: return "Keep Everything"
        case .removeKunaEvents: return "Remove Events Only"
        case .archiveCalendars: return "Archive Calendars"
        case .deleteEverything: return "Delete Everything"
        }
    }
    
    var description: String {
        return displayName
    }
    
    var detailDescription: String {
        switch self {
        case .keepEverything: return "Keep calendars and events (recommended)"
        case .removeKunaEvents: return "Remove Kuna events only, keep empty calendars"
        case .archiveCalendars: return "Rename calendars with '(Archive)' and stop syncing"
        case .deleteEverything: return "Delete all Kuna calendars and events permanently"
        }
    }
}

// MARK: - Color Extension (with simple cache for hex -> UIColor)
extension Color {
    private final class UIColorBox { let color: UIColor; init(_ c: UIColor) { color = c } }
    private static let _hexCache = NSCache<NSString, UIColorBox>()

    init?(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased() as NSString
        
        // Validate that the normalized string contains only hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard (normalized as String).unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            return nil
        }
        
        // Check valid lengths
        guard [3, 6, 8].contains((normalized as String).count) else {
            return nil
        }
        
        if let cached = Self._hexCache.object(forKey: normalized) {
            self = Color(cached.color)
            return
        }

        var int: UInt64 = 0
        guard Scanner(string: normalized as String).scanHexInt64(&int) else {
            return nil
        }
        
        let a, r, g, b: UInt64
        switch (normalized as String).count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        let ui = UIColor(
            red: CGFloat(Double(r) / 255),
            green: CGFloat(Double(g) / 255),
            blue: CGFloat(Double(b) / 255),
            alpha: CGFloat(Double(a) / 255)
        )
        Self._hexCache.setObject(UIColorBox(ui), forKey: normalized)
        self = Color(ui)
    }
}
