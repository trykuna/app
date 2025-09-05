// KunaTests/CalendarSyncEngineTests.swift
import XCTest
import EventKit
@testable import Kuna

@MainActor
final class CalendarSyncEngineTests: XCTestCase {
    
    var mockEventKitClient: EventKitClientMock!
    var engine: CalendarSyncEngine!
    
    // Skip tests in CI environment where EventKit is not available
    static let isCI = ProcessInfo.processInfo.environment["CI"] != nil
    
    override func setUp() async throws {
        try await super.setUp()
        mockEventKitClient = EventKitClientMock()
        engine = CalendarSyncEngine(eventKitClient: mockEventKitClient)
        // Note: We'll skip setAPI for now since MockVikunjaAPI doesn't inherit from VikunjaAPI
    }
    
    override func tearDown() async throws {
        engine = nil
        mockEventKitClient = nil
        try await super.tearDown()
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingBegin() async {
        await engine.onboardingBegin()
        
        // Should clear state
        XCTAssertTrue(engine.syncErrors.isEmpty)
    }
    
    func testOnboardingCompleteSingleMode() async throws {
        try XCTSkipIf(Self.isCI, "EventKit tests are skipped in CI environment")
        
        // Skip if no writable source is available
        guard mockEventKitClient.writableSource() != nil else {
            throw XCTSkip("No writable EventKit source available in test environment")
        }
        
        // Setup mock to succeed
        mockEventKitClient.shouldThrowOnAccess = false
        
        // Complete onboarding
        _ = try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1", "2"]
        )
        
        // Verify calendar was created
        XCTAssertEqual(mockEventKitClient.mockCalendars.count, 1)
        XCTAssertTrue(mockEventKitClient.mockCalendars.values.contains { $0.name == "Kuna" })
        
        XCTAssertTrue(engine.isEnabled)
    }
    
    func testOnboardingCompletePerProjectMode() async throws {
        try XCTSkipIf(Self.isCI, "EventKit tests are skipped in CI environment")
        
        // Skip if no writable source is available
        guard mockEventKitClient.writableSource() != nil else {
            throw XCTSkip("No writable EventKit source available in test environment")
        }
        
        // Setup mock to succeed
        mockEventKitClient.shouldThrowOnAccess = false
        
        // Complete onboarding
        _ = try await engine.onboardingComplete(
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
            _ = try await engine.onboardingComplete(
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
    
    // Note: Complex sync tests are simplified for now due to API dependency complexity
    // These would need a proper API abstraction layer to test effectively
    
    // MARK: - Disable Tests
    
    func testDisableSyncKeepEverything() async throws {
        try XCTSkipIf(Self.isCI, "EventKit tests are skipped in CI environment")
        
        // Skip if no writable source is available
        guard mockEventKitClient.writableSource() != nil else {
            throw XCTSkip("No writable EventKit source available in test environment")
        }
        
        // Setup and enable sync
        mockEventKitClient.shouldThrowOnAccess = false
        _ = try await engine.onboardingComplete(
            mode: .single,
            selectedProjectIDs: ["1"]
        )
        
        XCTAssertTrue(engine.isEnabled)
        
        // Disable with keep everything
        try await engine.disableSync(disposition: .keepEverything)
        
        // Should be disabled
        XCTAssertFalse(engine.isEnabled)
    }
}

// MARK: - Mock VikunjaAPI

class MockVikunjaAPI {
    var mockTasks: [VikunjaTask] = []
    var mockProjects: [Project] = []
    var shouldThrowError = false
    
    func fetchTasks(projectId: Int) async throws -> [VikunjaTask] {
        if shouldThrowError {
            throw MockAPIError.mockError
        }
        return mockTasks.filter { $0.projectId == projectId }
    }
    
    func fetchProjects() async throws -> [Project] {
        if shouldThrowError {
            throw MockAPIError.mockError
        }
        return mockProjects
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
