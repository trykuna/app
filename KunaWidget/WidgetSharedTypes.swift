// KunaWidget/WidgetSharedTypes.swift
import Foundation
import Security
import SwiftUI

// MARK: - Widget Model Types (copied from main app)

struct WidgetProject: Identifiable, Decodable {
    let id: Int
    let title: String
    let description: String?
}

enum WidgetTaskPriority: Int, CaseIterable, Identifiable, Codable {
    case unset = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    case doNow = 5
    
    var id: Int { rawValue }
    
    var color: Color {
        switch self {
        case .unset, .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        case .doNow: return .purple
        }
    }
    
    var systemImage: String {
        switch self {
        case .unset: return ""
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark"
        case .urgent: return "exclamationmark.2"
        case .doNow: return "exclamationmark.3"
        }
    }
}

struct WidgetVikunjaTask: Identifiable, Decodable {
    let id: Int
    var title: String
    var description: String?
    var done: Bool
    var dueDate: Date?
    var startDate: Date?
    var endDate: Date?
    var priority: WidgetTaskPriority
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, done, priority
        case dueDate = "due_date"
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
        
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
        
        // Handle priority - default to unset if missing
        let priorityValue = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        priority = WidgetTaskPriority(rawValue: priorityValue) ?? .unset
    }
}

// MARK: - Widget API Types

struct WidgetVikunjaConfig {
    var baseURL: URL
}

enum WidgetAPIError: Error {
    case badURL, missingToken, http(Int), decoding
}

// MARK: - Widget Vikunja API
class WidgetVikunjaAPI {
    private let config: WidgetVikunjaConfig
    private let token: String
    
    init(config: WidgetVikunjaConfig, token: String) {
        self.config = config
        self.token = token
    }
    
    private func request(_ path: String, method: String = "GET") async throws -> Data {
        let urlString = config.baseURL.absoluteString + (config.baseURL.absoluteString.hasSuffix("/") ? "" : "/") + path
        guard let url = URL(string: urlString) else { throw WidgetAPIError.badURL }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw WidgetAPIError.http(0) }
        guard (200..<300).contains(http.statusCode) else { throw WidgetAPIError.http(http.statusCode) }
        
        return data
    }
    
    func fetchProjects() async throws -> [WidgetProject] {
        let data = try await request("projects")
        return try JSONDecoder.widgetVikunja.decode([WidgetProject].self, from: data)
    }
    
    func fetchTasks(projectId: Int) async throws -> [WidgetVikunjaTask] {
        let data = try await request("projects/\(projectId)/tasks")
        return try JSONDecoder.widgetVikunja.decode([WidgetVikunjaTask].self, from: data)
    }
}

// MARK: - JSON helpers for widget
extension JSONDecoder {
    static var widgetVikunja: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - Keychain Helpers
private let appGroupIdentifier = "group.tech.systemsmystery.kuna"

func readWidgetToken() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "vikunja-token",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecAttrAccessGroup as String: appGroupIdentifier
    ]
    var out: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &out)
    print("Widget: readWidgetToken status: \(status)")
    guard status == errSecSuccess, let data = out as? Data else { 
        print("Widget: Failed to read token, status: \(status)")
        return nil 
    }
    let token = String(decoding: data, as: UTF8.self)
    print("Widget: Token read successfully, length: \(token.count)")
    return token
}

func readWidgetServerURL() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "vikunja-server",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecAttrAccessGroup as String: appGroupIdentifier
    ]
    var out: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &out)
    print("Widget: readWidgetServerURL status: \(status)")
    guard status == errSecSuccess, let data = out as? Data else { 
        print("Widget: Failed to read server URL, status: \(status)")
        return nil 
    }
    let url = String(decoding: data, as: UTF8.self)
    print("Widget: Server URL read successfully: \(url)")
    return url
}