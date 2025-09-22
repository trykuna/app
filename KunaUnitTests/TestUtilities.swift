import XCTest
@testable import Kuna
import Foundation

// MARK: - Shared Mock Classes

class MockTaskUpdateAPI {
    var updateTaskCalled: Bool = false
    var updateTaskResult: VikunjaTask?
    var shouldThrowError = false
    
    func updateTask(_ task: VikunjaTask) async throws -> VikunjaTask {
        updateTaskCalled = true
        
        if shouldThrowError {
            throw MockUpdateError.updateFailed
        }
        
        return updateTaskResult ?? task
    }
}

enum MockUpdateError: Error {
    case updateFailed
    
    var localizedDescription: String {
        switch self {
        case .updateFailed: return "Mock Update Failed"
        }
    }
}

// MARK: - VikunjaTask Test Helper

extension VikunjaTask {
    // Test initializer to create tasks easily
    static func makeTestTask(
        id: Int,
        title: String,
        done: Bool = false,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        priority: TaskPriority = .unset,
        projectId: Int? = 1
    ) -> VikunjaTask {
        // Create minimal JSON data to decode into a VikunjaTask
        let json: [String: Any] = [
            "id": id,
            "title": title,
            "done": done,
            "priority": priority.rawValue,
            "project_id": projectId as Any,
            "due_date": dueDate?.ISO8601Format() as Any,
            "start_date": startDate?.ISO8601Format() as Any,
            "end_date": endDate?.ISO8601Format() as Any,
            "repeat_mode": RepeatMode.afterAmount.rawValue,
            "percent_done": 0.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try! decoder.decode(VikunjaTask.self, from: data)
    }
}
