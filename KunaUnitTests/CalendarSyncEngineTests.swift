// KunaTests/CalendarSyncEngineTests.swift
import XCTest
import EventKit
@testable import Kuna

@MainActor
final class CalendarSyncEngineTests: XCTestCase {
    
    var mockEventKitClient: EventKitClientMock!
    var mockAPI: MockVikunjaAPI!
    var engine: CalendarSyncEngine!
    
    override func setUp() async throws {
        await super.setUp()
        mockEventKitClient = EventKitClientMock()
        mockAPI = MockVikunjaAPI()
        engine = CalendarSyncEngine(eventKitClient: mockEventKitClient)
        engine.setAPI(mockAPI)
    }
    
    override func tearDown() async throws {
        engine = nil
        mockAPI = nil
        mockEventKitClient = nil
        await super.tearDown()
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingBegin() async {
        await engine.onboardingBegin()
        
        // Should clear state
        XCTAssertTrue(engine.syncErrors.isEmpty)
    }
    
    func testOnboardingCompleteSingleMode() async throws {
        // Setup mock to succeed
        mockEventKitClient.shouldThrowOnAccess = false
        
        // Complete onboarding
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Verify calendar was created
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 1)
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name == "Kuna" })
        
        XCTAssertTrue(engine.isEnabled)
    }
    
    func testOnboardingCompletePerProjectMode() async throws {
        // Setup mock to succeed
        mockEventKitClient.shouldThrowOnAccess = false
        mockAPI.mockProjects = [
            Project(id: 1, title: "Project One", description: nil),
            Project(id: 2, title: "Project Two", description: nil)
        ]
        
        // Complete onboarding
        try await engine.onboardingComplete(
            mode: .perProject,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Verify calendars were created
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 2)
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name.contains("Project 1") })
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name.contains("Project 2") })
        
        XCTAssertTrue(engine.isEnabled)
    }
    
    func testOnboardingCompleteFailsWithoutAccess() async {
        mockEventKitClient.shouldThrowOnAccess = true
        
        do {
            try await engine.onboardingComplete(
                mode: .single,
                selectedProjectIDs: ["1"]
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is EventKitError)
            XCTAssertFalse(engine.isEnabled)
        }
    }
    
    // MARK: - Sync Tests
    
    func testSyncTasksToEvents() async throws {
        // Setup engine in single mode
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Setup mock tasks
        let task1 = VikunjaTask(
            id: 1,
            title: "Task One",
            dueDate: Date().addingTimeInterval(86400),
            projectId: 1
        )
        let task2 = VikunjaTask(
            id: 2,
            title: "Task Two",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            projectId: 1
        )
        
        mockAPI.mockTasks = [task1, task2]
        
        // Perform sync
        await engine.resyncNow()
        
        // Verify events were created
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 2)
        XCTAssertTrue(mockEventKitClient.mockEvents.contains { $0.title == "Task One" })
        XCTAssertTrue(mockEventKitClient.mockEvents.contains { $0.title == "Task Two" })
    }
    
    func testSyncUpdatesExistingEvents() async throws {
        // Setup and create initial events
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Create initial task
        let initialTask = VikunjaTask(
            id: 1,
            title: "Original Title",
            dueDate: Date().addingTimeInterval(86400),
            projectId: 1
        )
        mockAPI.mockTasks = [initialTask]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
        XCTAssertTrue(mockEventKitClient.mockEvents.contains { $0.title == "Original Title" })
        
        // Update task and sync again
        let updatedTask = VikunjaTask(
            id: 1,
            title: "Updated Title",
            dueDate: Date().addingTimeInterval(86400),
            projectId: 1
        )
        mockAPI.mockTasks = [updatedTask]
        await engine.resyncNow()
        
        // Should still have one event but with updated title
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
        XCTAssertTrue(mockEventKitClient.mockEvents.contains { $0.title == "Updated Title" })
        XCTAssertFalse(mockEventKitClient.mockEvents.contains { $0.title == "Original Title" })
    }
    
    func testSyncRemovesDeletedTasks() async throws {
        // Setup and create initial events
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Create initial tasks
        let task1 = VikunjaTask(id: 1, title: "Task One", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        let task2 = VikunjaTask(id: 2, title: "Task Two", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        mockAPI.mockTasks = [task1, task2]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 2)
        
        // Remove one task and sync again
        mockAPI.mockTasks = [task1] // Only task1 remains
        await engine.resyncNow()
        
        // Should only have one event
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
        XCTAssertTrue(mockEventKitClient.mockEvents.contains { $0.title == "Task One" })
        XCTAssertFalse(mockEventKitClient.mockEvents.contains { $0.title == "Task Two" })
    }
    
    // MARK: - Mode Switching Tests
    
    func testSwitchFromSingleToPerProject() async throws {
        // Start in single mode
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Create some events
        let task1 = VikunjaTask(id: 1, title: "Task One", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        let task2 = VikunjaTask(id: 2, title: "Task Two", dueDate: Date().addingTimeInterval(86400), projectId: 2)
        mockAPI.mockTasks = [task1, task2]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 2)
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 1)
        
        // Switch to per-project mode
        try await engine.onboardingComplete(
            mode: .perProject,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Should now have per-project calendars
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 3) // Original + 2 new per-project
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name.contains("Project 1") })
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name.contains("Project 2") })
    }
    
    func testSwitchFromPerProjectToSingle() async throws {
        // Start in per-project mode
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .perProject,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Create some events
        let task1 = VikunjaTask(id: 1, title: "Task One", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        let task2 = VikunjaTask(id: 2, title: "Task Two", dueDate: Date().addingTimeInterval(86400), projectId: 2)
        mockAPI.mockTasks = [task1, task2]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 2)
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 2)
        
        // Switch to single mode
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Should now have single calendar
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name == "Kuna" })
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 2) // Events should be preserved
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncHandlesAPIError() async throws {
        // Setup engine
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Make API throw error
        mockAPI.shouldThrowError = true
        
        // Sync should handle error gracefully
        await engine.resyncNow()
        
        // Should have recorded error
        XCTAssertFalse(engine.syncErrors.isEmpty)
        XCTAssertTrue(engine.syncErrors.first?.contains("Mock API Error") ?? false)
    }
    
    func testSyncHandlesEventKitError() async throws {
        // Setup engine
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Make EventKit throw error on save
        mockEventKitClient.saveError = EventKitError.saveFailed
        
        // Add a task to sync
        let task = VikunjaTask(id: 1, title: "Task", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        mockAPI.mockTasks = [task]
        
        // Sync should handle error gracefully
        await engine.resyncNow()
        
        // Should have recorded error
        XCTAssertFalse(engine.syncErrors.isEmpty)
    }
    
    // MARK: - Disable Tests
    
    func testDisableSyncKeepEverything() async throws {
        // Setup and enable sync
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Create some events
        let task = VikunjaTask(id: 1, title: "Task", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        mockAPI.mockTasks = [task]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
        XCTAssertTrue(engine.isEnabled)
        
        // Disable with keep everything
        try await engine.disableSync(disposition: .keepEverything)
        
        // Should be disabled but events preserved
        XCTAssertFalse(engine.isEnabled)
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
    }
    
    func testDisableSyncRemoveEvents() async throws {
        // Setup and enable sync
        mockEventKitClient.shouldThrowOnAccess = false
        try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        // Create some events
        let task = VikunjaTask(id: 1, title: "Task", dueDate: Date().addingTimeInterval(86400), projectId: 1)
        mockAPI.mockTasks = [task]
        await engine.resyncNow()
        
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 1)
        
        // Disable with remove events
        try await engine.disableSync(disposition: .removeKunaEvents)
        
        // Should be disabled and events removed
        XCTAssertFalse(engine.isEnabled)
        XCTAssertEqual(mockEventKitClient.mockEvents.count, 0)
    }
}

// MARK: - Mock VikunjaAPI

class MockVikunjaAPI: VikunjaAPI {
    var mockTasks: [VikunjaTask] = []
    var mockProjects: [Project] = []
    var shouldThrowError = false
    
    override func fetchTasks(projectId: Int) async throws -> [VikunjaTask] {
        if shouldThrowError {
            throw MockAPIError.mockError
        }
        return mockTasks.filter { $0.projectId == projectId }
    }
}

enum MockAPIError: Error {
    case mockError
    
    var localizedDescription: String {
        switch self {
        case .mockError: return "Mock API Error"
        }
    }
}