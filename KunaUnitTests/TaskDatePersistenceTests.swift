import XCTest
@testable import Kuna
import Foundation

final class TaskDatePersistenceTests: XCTestCase {
    
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
    
    // MARK: - Date Change Persistence Tests
    
    func testStartDateChangeIsSaved() async throws {
        // Given: A task with no start date
        XCTAssertNil(testTask.startDate)
        
        // When: We update the start date
        let newStartDate = Date().addingTimeInterval(3600) // 1 hour from now
        testTask.startDate = newStartDate
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.startDate = newStartDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: The start date should be saved
        XCTAssertNotNil(savedTask.startDate)
        guard let startDate = savedTask.startDate else {
            XCTFail("Start date should not be nil")
            return
        }
        XCTAssertEqual(startDate.timeIntervalSince1970,
                      newStartDate.timeIntervalSince1970,
                      accuracy: 1.0)
        XCTAssertTrue(mockAPI.updateTaskCalled)
    }
    
    func testDueDateChangeIsSaved() async throws {
        // Given: A task with an existing due date
        let originalDueDate = Date()
        testTask.dueDate = originalDueDate
        
        // When: We update the due date
        let newDueDate = Date().addingTimeInterval(7200) // 2 hours from now
        testTask.dueDate = newDueDate
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.dueDate = newDueDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: The due date should be saved
        XCTAssertNotNil(savedTask.dueDate)
        guard let dueDate = savedTask.dueDate else {
            XCTFail("Due date should not be nil")
            return
        }
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                      newDueDate.timeIntervalSince1970,
                      accuracy: 1.0)
        XCTAssertNotEqual(dueDate.timeIntervalSince1970,
                         originalDueDate.timeIntervalSince1970,
                         accuracy: 1.0)
    }
    
    func testEndDateChangeIsSaved() async throws {
        // Given: A task with no end date
        XCTAssertNil(testTask.endDate)
        
        // When: We update the end date
        let newEndDate = Date().addingTimeInterval(10800) // 3 hours from now
        testTask.endDate = newEndDate
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.endDate = newEndDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: The end date should be saved
        XCTAssertNotNil(savedTask.endDate)
        guard let endDate = savedTask.endDate else {
            XCTFail("End date should not be nil")
            return
        }
        XCTAssertEqual(endDate.timeIntervalSince1970,
                      newEndDate.timeIntervalSince1970,
                      accuracy: 1.0)
    }
    
    func testMultipleDateChangesAreSaved() async throws {
        // Given: A task with no dates
        XCTAssertNil(testTask.startDate)
        XCTAssertNil(testTask.dueDate)
        XCTAssertNil(testTask.endDate)
        
        // When: We update all dates
        let baseTime = Date()
        let newStartDate = baseTime
        let newDueDate = baseTime.addingTimeInterval(3600)
        let newEndDate = baseTime.addingTimeInterval(7200)
        
        testTask.startDate = newStartDate
        testTask.dueDate = newDueDate
        testTask.endDate = newEndDate
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.startDate = newStartDate
        expectedUpdatedTask.dueDate = newDueDate
        expectedUpdatedTask.endDate = newEndDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: All dates should be saved
        XCTAssertNotNil(savedTask.startDate)
        XCTAssertNotNil(savedTask.dueDate)
        XCTAssertNotNil(savedTask.endDate)

        guard let startDate = savedTask.startDate,
              let dueDate = savedTask.dueDate,
              let endDate = savedTask.endDate else {
            XCTFail("All dates should not be nil")
            return
        }
        XCTAssertEqual(startDate.timeIntervalSince1970, newStartDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(dueDate.timeIntervalSince1970, newDueDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(endDate.timeIntervalSince1970, newEndDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testDateClearingIsSaved() async throws {
        // Given: A task with existing dates
        let existingDate = Date()
        testTask.startDate = existingDate
        testTask.dueDate = existingDate
        testTask.endDate = existingDate
        
        // When: We clear the dates
        testTask.startDate = nil
        testTask.dueDate = nil
        testTask.endDate = nil
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.startDate = nil
        expectedUpdatedTask.dueDate = nil
        expectedUpdatedTask.endDate = nil
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)
        
        // Then: All dates should be cleared
        XCTAssertNil(savedTask.startDate)
        XCTAssertNil(savedTask.dueDate)
        XCTAssertNil(savedTask.endDate)
    }
    
    // MARK: - Recurring Settings Persistence Tests
    
    func testRepeatAfterChangeIsSaved() async throws {
        // Given: A task with no repeat settings
        XCTAssertNil(testTask.repeatAfter)
        
        // When: We set repeat after (daily = 86400 seconds)
        let dailyRepeat = 86400
        testTask.repeatAfter = dailyRepeat
        testTask.repeatMode = .afterAmount
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = dailyRepeat
        expectedUpdatedTask.repeatMode = .afterAmount
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)
        
        // Then: The repeat settings should be saved
        XCTAssertNotNil(savedTask.repeatAfter)
        XCTAssertEqual(savedTask.repeatAfter, dailyRepeat)
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.afterAmount)
    }
    
    func testRepeatModeChangeIsSaved() async throws {
        // Given: A task with existing repeat settings
        testTask.repeatAfter = 86400 // Daily
        testTask.repeatMode = .afterAmount
        
        // When: We change the repeat mode
        testTask.repeatMode = .fromCurrentDate

        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = 86400
        expectedUpdatedTask.repeatMode = .fromCurrentDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: The repeat mode should be saved
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.fromCurrentDate)
        XCTAssertEqual(savedTask.repeatAfter, 86400) // Should remain unchanged
    }
    
    func testWeeklyRepeatIsSaved() async throws {
        // Given: A task with no repeat settings
        XCTAssertNil(testTask.repeatAfter)
        
        // When: We set weekly repeat (604800 seconds)
        let weeklyRepeat = 604800
        testTask.repeatAfter = weeklyRepeat
        testTask.repeatMode = .afterAmount
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = weeklyRepeat
        expectedUpdatedTask.repeatMode = .afterAmount
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)
        
        // Then: The weekly repeat should be saved
        XCTAssertEqual(savedTask.repeatAfter, weeklyRepeat)
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.afterAmount)
    }
    
    func testMonthlyRepeatIsSaved() async throws {
        // Given: A task with existing daily repeat
        testTask.repeatAfter = 86400 // Daily
        testTask.repeatMode = .afterAmount
        
        // When: We change to monthly repeat (2592000 seconds = 30 days)
        let monthlyRepeat = 2592000
        testTask.repeatAfter = monthlyRepeat
        testTask.repeatMode = .fromCurrentDate

        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = monthlyRepeat
        expectedUpdatedTask.repeatMode = .fromCurrentDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: The monthly repeat should be saved
        XCTAssertEqual(savedTask.repeatAfter, monthlyRepeat)
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.fromCurrentDate)
    }
    
    func testCustomRepeatIntervalIsSaved() async throws {
        // Given: A task with no repeat settings
        XCTAssertNil(testTask.repeatAfter)
        
        // When: We set a custom repeat interval (every 3 days = 259200 seconds)
        let customRepeat = 259200 // 3 days
        testTask.repeatAfter = customRepeat
        testTask.repeatMode = .afterAmount
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = customRepeat
        expectedUpdatedTask.repeatMode = .afterAmount
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)
        
        // Then: The custom repeat should be saved
        XCTAssertEqual(savedTask.repeatAfter, customRepeat)
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.afterAmount)
    }
    
    func testRepeatClearingIsSaved() async throws {
        // Given: A task with existing repeat settings
        testTask.repeatAfter = 86400
        testTask.repeatMode = .afterAmount
        
        // When: We clear the repeat settings
        testTask.repeatAfter = nil
        // Note: repeatMode typically stays set even when repeatAfter is nil
        
        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.repeatAfter = nil
        expectedUpdatedTask.repeatMode = .afterAmount
        mockAPI.updateTaskResult = expectedUpdatedTask
        
        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)
        
        // Then: The repeat after should be cleared
        XCTAssertNil(savedTask.repeatAfter)
        // repeatMode might still be set depending on implementation
    }
    
    // MARK: - Combined Date and Recurring Tests
    
    func testDateAndRecurringChangesAreSavedTogether() async throws {
        // Given: A task with no dates or repeat settings
        XCTAssertNil(testTask.startDate)
        XCTAssertNil(testTask.dueDate)
        XCTAssertNil(testTask.repeatAfter)
        
        // When: We set both dates and recurring
        let newDueDate = Date().addingTimeInterval(3600)
        let dailyRepeat = 86400
        
        testTask.dueDate = newDueDate
        testTask.repeatAfter = dailyRepeat
        testTask.repeatMode = .fromCurrentDate

        // Set up mock to return updated task
        var expectedUpdatedTask = testTask.copy()
        expectedUpdatedTask.dueDate = newDueDate
        expectedUpdatedTask.repeatAfter = dailyRepeat
        expectedUpdatedTask.repeatMode = .fromCurrentDate
        mockAPI.updateTaskResult = expectedUpdatedTask

        // When: We save the task
        let savedTask = try await mockAPI.updateTask(testTask)

        // Then: Both date and recurring should be saved
        XCTAssertNotNil(savedTask.dueDate)
        guard let dueDate = savedTask.dueDate else {
            XCTFail("Due date should not be nil")
            return
        }
        XCTAssertEqual(dueDate.timeIntervalSince1970, newDueDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(savedTask.repeatAfter, dailyRepeat)
        XCTAssertEqual(savedTask.repeatMode, RepeatMode.fromCurrentDate)
    }
    
    // MARK: - Error Handling Tests
    
    func testDateChangeFailureHandling() async throws {
        // Given: A task with a date change
        testTask.dueDate = Date()
        
        // When: The API call fails
        mockAPI.shouldThrowError = true
        
        // Then: The error should be thrown
        do {
            _ = try await mockAPI.updateTask(testTask)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockUpdateError)
        }
    }
    
    func testRecurringChangeFailureHandling() async throws {
        // Given: A task with recurring changes
        testTask.repeatAfter = 86400
        testTask.repeatMode = .afterAmount
        
        // When: The API call fails
        mockAPI.shouldThrowError = true
        
        // Then: The error should be thrown
        do {
            _ = try await mockAPI.updateTask(testTask)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockUpdateError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestTask() -> VikunjaTask {
        return VikunjaTask(
            id: 1,
            title: "Test Task",
            description: "A test task for date and recurring tests",
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
}

// MARK: - VikunjaTask Copy Extension

extension VikunjaTask {
    func copy() -> VikunjaTask {
        return VikunjaTask(
            id: self.id,
            title: self.title,
            description: self.description,
            done: self.done,
            dueDate: self.dueDate,
            startDate: self.startDate,
            endDate: self.endDate,
            labels: self.labels,
            reminders: self.reminders,
            priority: self.priority,
            percentDone: self.percentDone,
            hexColor: self.hexColor,
            repeatAfter: self.repeatAfter,
            repeatMode: self.repeatMode,
            assignees: self.assignees,
            createdBy: self.createdBy,
            projectId: self.projectId,
            isFavorite: self.isFavorite,
            attachments: self.attachments,
            commentCount: self.commentCount,
            updatedAt: self.updatedAt,
            relations: self.relations
        )
    }
}