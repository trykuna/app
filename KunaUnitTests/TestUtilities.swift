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
