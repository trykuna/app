// Models/VikunjaModels.swift
import Foundation
import SwiftUI

struct AuthResponse: Decodable {
    let token: String
}

struct Project: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String?
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
        Color(hex: hexColor ?? "007AFF") // Default to blue
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
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Handle hex_color more carefully - it might be missing or null
        if let colorString = try container.decodeIfPresent(String.self, forKey: .hexColor),
           !colorString.isEmpty {
            hexColor = colorString
        } else {
            hexColor = nil
        }
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
    
    var color: Color {
        Color(hex: hexColor ?? "007AFF") // Default to blue if no color set
    }
    
    var hasCustomColor: Bool {
        hexColor != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, done, labels, reminders, priority
        case dueDate = "due_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case percentDone = "percent_done"
        case hexColor = "hex_color"
        case repeatAfter = "repeat_after"
        case repeatMode = "repeat_mode"
    }
    
    // Custom decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
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
        
        if let dueDate = dueDate {
            try container.encode(formatter.string(from: dueDate), forKey: .dueDate)
        }
        
        if let startDate = startDate {
            try container.encode(formatter.string(from: startDate), forKey: .startDate)
        }
        
        if let endDate = endDate {
            try container.encode(formatter.string(from: endDate), forKey: .endDate)
        }
        
        try container.encodeIfPresent(labels, forKey: .labels)
        try container.encodeIfPresent(reminders, forKey: .reminders)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
