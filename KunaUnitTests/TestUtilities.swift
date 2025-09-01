import XCTest
@testable import Kuna
import Foundation

// MARK: - Shared Mock Classes

class MockTaskUpdateAPI: MockVikunjaAPI {
    var updateTaskCalled: Bool = false
    var updateTaskResult: VikunjaTask?
    
    func updateTask(_ task: VikunjaTask) async throws -> VikunjaTask {
        updateTaskCalled = true
        
        if shouldThrowError {
            throw MockAPIError.mockError
        }
        
        return updateTaskResult ?? task
    }
}
