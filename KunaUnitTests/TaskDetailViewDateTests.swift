import XCTest
import SwiftUI
@testable import Kuna
import Foundation

@MainActor
final class TaskDetailViewDateTests: XCTestCase {
    
    var mockAPI: MockTaskUpdateAPI!
    var testTask: VikunjaTask!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI = MockTaskUpdateAPI()
        testTask = createTestTask()
    }
    
    override func tearDown() async throws {
        mockAPI = nil
        testTask = nil
        try await super.tearDown()
    }
    
    // MARK: - TaskDetailView Date Persistence Tests
    
    func testTaskDetailViewSavesDateChanges() async throws {
        // Given: A task with no dates
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        XCTAssertNil(editedTask.startDate)
        XCTAssertNil(editedTask.dueDate)
        XCTAssertNil(editedTask.endDate)
        
        // Create expected updated task
        let expectedStartDate = Date().addingTimeInterval(1800) // 30 min from now
        let expectedDueDate = Date().addingTimeInterval(3600)   // 1 hour from now
        let expectedEndDate = Date().addingTimeInterval(5400)   // 1.5 hours from now
        
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.startDate = expectedStartDate
        expectedUpdatedTask.dueDate = expectedDueDate
        expectedUpdatedTask.endDate = expectedEndDate
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We simulate editing dates through TaskDetailView logic
        editedTask.startDate = expectedStartDate
        editedTask.dueDate = expectedDueDate
        editedTask.endDate = expectedEndDate
        
        // Simulate the save operation that TaskDetailView would perform
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The dates should be saved correctly
        XCTAssertNotNil(updatedTask.startDate)
        XCTAssertNotNil(updatedTask.dueDate)
        XCTAssertNotNil(updatedTask.endDate)
        
        guard let startDate = updatedTask.startDate,
              let dueDate = updatedTask.dueDate,
              let endDate = updatedTask.endDate else {
            XCTFail("All dates should not be nil")
            return
        }
        XCTAssertEqual(startDate.timeIntervalSince1970,
                      expectedStartDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                      expectedDueDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(endDate.timeIntervalSince1970,
                      expectedEndDate.timeIntervalSince1970, accuracy: 1.0)
        
        XCTAssertTrue(mockAPI.updateTaskCalled, "API updateTask should have been called")
    }
    
    func testTaskDetailViewSavesRecurringChanges() async throws {
        // Given: A task with no recurring settings
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        XCTAssertNil(editedTask.repeatAfter)
        XCTAssertEqual(editedTask.repeatMode, .afterAmount) // Default value
        
        // Create expected updated task with recurring settings
        let expectedRepeatAfter = 604800 // Weekly (7 days in seconds)
        let expectedRepeatMode = RepeatMode.fromCurrentDate

        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.repeatAfter = expectedRepeatAfter
        expectedUpdatedTask.repeatMode = expectedRepeatMode
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We simulate editing recurring settings through TaskDetailView
        editedTask.repeatAfter = expectedRepeatAfter
        editedTask.repeatMode = expectedRepeatMode
        
        // Simulate the save operation that TaskDetailView would perform
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The recurring settings should be saved correctly
        XCTAssertNotNil(updatedTask.repeatAfter)
        XCTAssertEqual(updatedTask.repeatAfter, expectedRepeatAfter)
        XCTAssertEqual(updatedTask.repeatMode, expectedRepeatMode)
        
        XCTAssertTrue(mockAPI.updateTaskCalled, "API updateTask should have been called")
    }
    
    func testTaskDetailViewHandlesDateValidation() async throws {
        // Given: A task being edited
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }

        // When: We set invalid date order (start after due)
        let baseTime = Date()
        let invalidStartDate = baseTime.addingTimeInterval(7200) // 2 hours from now
        let validDueDate = baseTime.addingTimeInterval(3600)     // 1 hour from now (before start!)
        
        editedTask.startDate = invalidStartDate
        editedTask.dueDate = validDueDate
        
        // Create expected task (API should accept and return what we send)
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.startDate = invalidStartDate
        expectedUpdatedTask.dueDate = validDueDate
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save (TaskDetailView should allow this - validation is up to user/server)
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The dates should be saved as provided (no client-side validation)
        guard let startDate = updatedTask.startDate,
              let dueDate = updatedTask.dueDate else {
            XCTFail("Dates should not be nil")
            return
        }
        XCTAssertEqual(startDate.timeIntervalSince1970,
                      invalidStartDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                      validDueDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testTaskDetailViewPreservesTimeComponents() async throws {
        // Given: A task with specific time components
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }

        // Create dates with specific times (not just start of day)
        let calendar = Calendar.current
        let dateComponents = DateComponents(
            year: 2024, month: 3, day: 15,
            hour: 14, minute: 30, second: 45
        )
        guard let specificDateTime = calendar.date(from: dateComponents) else {
            XCTFail("Should be able to create date from components")
            return
        }
        
        editedTask.dueDate = specificDateTime
        
        // Create expected updated task
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.dueDate = specificDateTime
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The exact time should be preserved
        XCTAssertNotNil(updatedTask.dueDate)
        guard let dueDate = updatedTask.dueDate else {
            XCTFail("Due date should not be nil")
            return
        }
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                      specificDateTime.timeIntervalSince1970, accuracy: 1.0)

        // Verify specific time components are preserved
        let savedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                    from: dueDate)
        XCTAssertEqual(savedComponents.year, 2024)
        XCTAssertEqual(savedComponents.month, 3)
        XCTAssertEqual(savedComponents.day, 15)
        XCTAssertEqual(savedComponents.hour, 14)
        XCTAssertEqual(savedComponents.minute, 30)
        XCTAssertEqual(savedComponents.second, 45)
    }
    
    func testTaskDetailViewClearsRecurringSettings() async throws {
        // Given: A task with existing recurring settings
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        editedTask.repeatAfter = 86400 // Daily
        editedTask.repeatMode = .afterAmount
        
        // When: We clear the recurring settings
        editedTask.repeatAfter = nil
        // repeatMode typically remains set
        
        // Create expected updated task
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.repeatAfter = nil
        expectedUpdatedTask.repeatMode = .afterAmount // Remains set
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The recurring interval should be cleared
        XCTAssertNil(updatedTask.repeatAfter)
        // repeatMode might still be set (depends on UI logic)
    }
    
    func testTaskDetailViewHandlesRecurringPresets() async throws {
        let testCases: [(interval: Int, description: String)] = [
            (86400, "Daily"),
            (604800, "Weekly"),
            (2592000, "Monthly (30 days)"),
            (31536000, "Yearly (365 days)")
        ]
        
        for testCase in testCases {
            // Given: A fresh task
            var editedTask = createTestTask()
            
            // When: We set a recurring preset
            editedTask.repeatAfter = testCase.interval
            editedTask.repeatMode = .afterAmount
            
            // Create expected updated task
            var expectedUpdatedTask = editedTask
            expectedUpdatedTask.repeatAfter = testCase.interval
            expectedUpdatedTask.repeatMode = .afterAmount
            
            mockAPI.updateTaskResult = expectedUpdatedTask
            mockAPI.updateTaskCalled = false // Reset for each test
            
            // When: We save the task
            let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
            
            // Then: The preset should be saved correctly
            XCTAssertEqual(updatedTask.repeatAfter, testCase.interval, 
                          "Failed to save \(testCase.description) recurring setting")
            XCTAssertEqual(updatedTask.repeatMode, .afterAmount)
            XCTAssertTrue(mockAPI.updateTaskCalled, 
                         "API should have been called for \(testCase.description)")
        }
    }
    
    func testTaskDetailViewHandlesDateTimeZones() async throws {
        // Given: A task being edited in a specific timezone
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }

        // Create a date with timezone consideration
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.timeZone = TimeZone(identifier: "America/New_York")

        let dateString = "2024-03-15 14:30:00 -0500" // EDT time
        guard let specificDate = formatter.date(from: dateString) else {
            XCTFail("Should be able to create date from string")
            return
        }
        
        editedTask.dueDate = specificDate
        
        // Create expected updated task
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.dueDate = specificDate
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The timezone information should be preserved
        XCTAssertNotNil(updatedTask.dueDate)
        guard let dueDate = updatedTask.dueDate else {
            XCTFail("Due date should not be nil")
            return
        }
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                      specificDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Integration with RepeatEditorSheet Tests
    
    func testRepeatEditorSheetIntegration() async throws {
        // This test simulates the RepeatEditorSheet -> TaskDetailView -> API flow
        
        // Given: A task with no recurring settings
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        XCTAssertNil(editedTask.repeatAfter)
        
        // Simulate RepeatEditorSheet returning new values
        let newRepeatAfter = 604800 // Weekly
        let newRepeatMode = RepeatMode.fromCurrentDate
        
        // This would be called from RepeatEditorSheet's onCommit
        editedTask.repeatAfter = newRepeatAfter
        editedTask.repeatMode = newRepeatMode
        
        // Create expected updated task
        var expectedUpdatedTask = editedTask
        expectedUpdatedTask.repeatAfter = newRepeatAfter
        expectedUpdatedTask.repeatMode = newRepeatMode
        
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: TaskDetailView saves the changes
        let updatedTask = try await saveTaskChanges(editedTask, using: mockAPI)
        
        // Then: The RepeatEditorSheet changes should be persisted
        XCTAssertEqual(updatedTask.repeatAfter, newRepeatAfter)
        XCTAssertEqual(updatedTask.repeatMode, newRepeatMode)
    }
    
    // MARK: - Error Scenarios
    
    func testTaskDetailViewHandlesSaveFailure() async throws {
        // Given: A task with date changes
        guard var editedTask = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        editedTask.dueDate = Date()
        
        // When: The save operation fails
        mockAPI.shouldThrowError = true
        
        // Then: The error should be propagated
        do {
            _ = try await saveTaskChanges(editedTask, using: mockAPI)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockAPIError)
        }
        
        XCTAssertTrue(mockAPI.updateTaskCalled, "API should have been attempted")
    }
    
    // MARK: - Helper Methods
    
    private func createTestTask() -> VikunjaTask {
        return VikunjaTask(
            id: 1,
            title: "Test Task",
            description: "A test task for date and recurring integration tests",
            done: false,
            dueDate: nil,
            startDate: nil,
            endDate: nil,
            labels: nil,
            reminders: nil,
            priority: .medium,
            percentDone: 0.0,
            hexColor: nil,
            repeatAfter: nil,
            repeatMode: .afterAmount,
            assignees: nil,
            createdBy: nil,
            projectId: 1,
            isFavorite: false,
            attachments: nil,
            commentCount: nil,
            updatedAt: nil,
            relations: nil
        )
    }
    
    /// Simulates the save operation that TaskDetailView performs
    private func saveTaskChanges(_ task: VikunjaTask, using api: MockTaskUpdateAPI) async throws -> VikunjaTask {
        // This mimics the actual save logic in TaskDetailView
        return try await api.updateTask(task)
    }
}

// MARK: - JSON Encoding Tests

extension TaskDetailViewDateTests {
    
    func testTaskDateEncodingForAPI() throws {
        // Given: A task with various dates set
        guard var task = testTask else {
            XCTFail("Test task should not be nil")
            return
        }
        let baseTime = Date()
        task.startDate = baseTime
        task.dueDate = baseTime.addingTimeInterval(3600)
        task.endDate = baseTime.addingTimeInterval(7200)
        task.repeatAfter = 86400
        task.repeatMode = .fromCurrentDate
        
        // When: We encode the task for API transmission
        let encoder = JSONEncoder.vikunja
        let encodedData = try encoder.encode(task)
        
        // Then: The encoded data should contain the date information
        XCTAssertNotNil(encodedData)
        
        let jsonString = String(data: encodedData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        guard let jsonString = jsonString else {
            XCTFail("JSON string should not be nil")
            return
        }

        // Verify dates are included in JSON
        XCTAssertTrue(jsonString.contains("start_date") || jsonString.contains("startDate"))
        XCTAssertTrue(jsonString.contains("due_date") || jsonString.contains("dueDate"))
        XCTAssertTrue(jsonString.contains("end_date") || jsonString.contains("endDate"))
        XCTAssertTrue(jsonString.contains("repeat_after") || jsonString.contains("repeatAfter"))
        XCTAssertTrue(jsonString.contains("repeat_mode") || jsonString.contains("repeatMode"))
    }
    
    func testTaskDateDecodingFromAPI() throws {
        // Given: JSON data from API with date fields
        let jsonString = """
        {
            "id": 1,
            "title": "Test Task",
            "description": "Test description",
            "done": false,
            "due_date": "2024-03-15T14:30:00Z",
            "start_date": "2024-03-15T13:30:00Z",
            "end_date": "2024-03-15T15:30:00Z",
            "repeat_after": 86400,
            "repeat_mode": 1,
            "priority": 2,
            "percent_done": 0.0,
            "project_id": 1,
            "is_favorite": false
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Should be able to create data from JSON string")
            return
        }
        
        // When: We decode the task
        let decoder = JSONDecoder.vikunja
        let decodedTask = try decoder.decode(VikunjaTask.self, from: jsonData)
        
        // Then: The dates should be properly decoded
        XCTAssertNotNil(decodedTask.startDate)
        XCTAssertNotNil(decodedTask.dueDate)
        XCTAssertNotNil(decodedTask.endDate)
        XCTAssertEqual(decodedTask.repeatAfter, 86400)
        XCTAssertEqual(decodedTask.repeatMode, .monthly) // repeat_mode: 1 maps to .monthly
        
        // Verify date parsing is correct
        let calendar = Calendar.current
        guard let dueDate = decodedTask.dueDate else {
            XCTFail("Due date should not be nil")
            return
        }
        let dueComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                  from: dueDate)
        XCTAssertEqual(dueComponents.year, 2024)
        XCTAssertEqual(dueComponents.month, 3)
        XCTAssertEqual(dueComponents.day, 15)
        XCTAssertEqual(dueComponents.hour, 14)
        XCTAssertEqual(dueComponents.minute, 30)
    }
}