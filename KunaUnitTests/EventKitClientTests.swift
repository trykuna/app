// KunaTests/EventKitClientTests.swift
import XCTest
import EventKit
@testable import Kuna

final class EventKitClientTests: XCTestCase {
    
    var mockClient: EventKitClientMock!
    
    override func setUp() {
        super.setUp()
        mockClient = EventKitClientMock()
    }
    
    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }
    
    // MARK: - Access Request Tests
    
    func testRequestAccessSuccess() async throws {
        mockClient.shouldThrowOnAccess = false
        
        try await mockClient.requestAccess()
        // Should not throw
    }
    
    func testRequestAccessFailure() async {
        mockClient.shouldThrowOnAccess = true
        
        do {
            try await mockClient.requestAccess()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is EventKitError)
        }
    }
    
    // MARK: - Calendar Management Tests
    
    func testEnsureCalendarCreation() throws {
        guard let source = mockClient.writableSource() else {
            XCTFail("Should have a writable source")
            return
        }
        let calendar = try mockClient.ensureCalendar(named: "Test Calendar", in: source)
        
        XCTAssertEqual(calendar.title, "Test Calendar")
        XCTAssertEqual(calendar.source, source)
        XCTAssertTrue(mockClient.mockCalendars.contains { $0.value.name == "Test Calendar" })
    }
    
    func testCalendarsRetrieval() throws {
        guard let source = mockClient.writableSource() else {
            XCTFail("Should have a writable source")
            return
        }
        let calendar1 = try mockClient.ensureCalendar(named: "Calendar 1", in: source)
        let calendar2 = try mockClient.ensureCalendar(named: "Calendar 2", in: source)
        
        let identifiers = [calendar1.calendarIdentifier, calendar2.calendarIdentifier]
        let retrievedCalendars = mockClient.calendars(for: identifiers)
        
        XCTAssertEqual(retrievedCalendars.count, 2)
    }
    
    // MARK: - Event Operations Tests
    
    func testEventSaveSuccess() throws {
        guard let source = mockClient.writableSource() else {
            XCTFail("Should have a writable source")
            return
        }
        let calendar = try mockClient.ensureCalendar(named: "Test Calendar", in: source)
        
        let event = EKEvent(eventStore: mockClient.store)
        event.title = "Test Event"
        event.calendar = calendar
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        
        try mockClient.save(event: event)
        try mockClient.commit()
        
        XCTAssertTrue(mockClient.mockEvents.contains { $0.title == "Test Event" })
    }
    
    func testEventSaveFailure() throws {
        mockClient.saveError = EventKitError.saveFailed
        
        let event = EKEvent(eventStore: mockClient.store)
        event.title = "Test Event"
        
        XCTAssertThrowsError(try mockClient.save(event: event)) { error in
            XCTAssertTrue(error is EventKitError)
        }
    }
    
    func testEventRemoval() throws {
        // First add an event
        guard let source = mockClient.writableSource() else {
            XCTFail("Should have a writable source")
            return
        }
        let calendar = try mockClient.ensureCalendar(named: "Test Calendar", in: source)
        
        let event = EKEvent(eventStore: mockClient.store)
        event.title = "Test Event"
        event.calendar = calendar
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        
        try mockClient.save(event: event)
        try mockClient.commit()
        
        XCTAssertTrue(mockClient.mockEvents.contains { $0.title == "Test Event" })
        
        // Then remove it
        try mockClient.remove(event: event)
        try mockClient.commit()
        
        XCTAssertFalse(mockClient.mockEvents.contains { $0.title == "Test Event" })
    }
    
    func testCommitFailure() {
        mockClient.commitError = EventKitError.commitFailed
        
        XCTAssertThrowsError(try mockClient.commit()) { error in
            XCTAssertTrue(error is EventKitError)
        }
    }
    
    // MARK: - Event Filtering Tests
    
    func testEventsInDateRange() throws {
        guard let source = mockClient.writableSource() else {
            XCTFail("Should have a writable source")
            return
        }
        let calendar = try mockClient.ensureCalendar(named: "Test Calendar", in: source)
        
        let now = Date()
        let pastDate = now.addingTimeInterval(-86400) // 1 day ago
        let futureDate = now.addingTimeInterval(86400) // 1 day from now
        
        // Add events at different times
        let pastEvent = EKEvent(eventStore: mockClient.store)
        pastEvent.title = "Past Event"
        pastEvent.calendar = calendar
        pastEvent.startDate = pastDate
        pastEvent.endDate = pastDate.addingTimeInterval(3600)
        
        let futureEvent = EKEvent(eventStore: mockClient.store)
        futureEvent.title = "Future Event"
        futureEvent.calendar = calendar
        futureEvent.startDate = futureDate
        futureEvent.endDate = futureDate.addingTimeInterval(3600)
        
        try mockClient.save(event: pastEvent)
        try mockClient.save(event: futureEvent)
        try mockClient.commit()
        
        // Query for events in a specific range
        let rangeStart = now.addingTimeInterval(-3600) // 1 hour ago
        let rangeEnd = now.addingTimeInterval(3600 * 25) // 25 hours from now
        
        let eventsInRange = mockClient.events(in: [calendar], start: rangeStart, end: rangeEnd)
        
        // Should only get the future event
        XCTAssertEqual(eventsInRange.count, 1)
        XCTAssertEqual(eventsInRange.first?.title, "Future Event")
    }
}

// MARK: - EKEvent Extension Tests

final class EKEventExtensionTests: XCTestCase {
    
    var eventStore: EKEventStore!
    
    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
    }
    
    override func tearDown() {
        eventStore = nil
        super.tearDown()
    }
    
    func testKunaEventIdentificationByURL() {
        let event = EKEvent(eventStore: eventStore)
        
        // Initially not a Kuna event
        XCTAssertFalse(event.isKunaEvent)
        
        // Set Kuna URL
        event.url = URL(string: "kuna://task/123?project=456")
        XCTAssertTrue(event.isKunaEvent)
        
        // Set non-Kuna URL
        event.url = URL(string: "https://example.com")
        XCTAssertFalse(event.isKunaEvent)
    }
    
    func testKunaEventIdentificationByNotes() {
        let event = EKEvent(eventStore: eventStore)
        
        // Initially not a Kuna event
        XCTAssertFalse(event.isKunaEvent)
        
        // Set Kuna notes marker
        event.notes = "Some description\n\nKUNA_EVENT: task=123 project=456"
        XCTAssertTrue(event.isKunaEvent)
        
        // Set notes without marker
        event.notes = "Just a regular note"
        XCTAssertFalse(event.isKunaEvent)
    }
    
    func testSetKunaTaskInfo() {
        let event = EKEvent(eventStore: eventStore)
        event.setKunaTaskInfo(taskID: 123, projectID: 456)
        
        XCTAssertEqual(event.url?.absoluteString, "kuna://task/123?project=456")
        XCTAssertTrue(event.notes?.contains("KUNA_EVENT: task=123 project=456") ?? false)
    }
    
    func testSetKunaTaskInfoWithExistingNotes() {
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Existing notes"
        event.setKunaTaskInfo(taskID: 789, projectID: 101)
        
        XCTAssertTrue(event.notes?.contains("Existing notes") ?? false)
        XCTAssertTrue(event.notes?.contains("KUNA_EVENT: task=789 project=101") ?? false)
    }
    
    func testExtractTaskInfoFromURL() {
        let event = EKEvent(eventStore: eventStore)
        event.url = URL(string: "kuna://task/123?project=456")
        
        let taskInfo = event.extractTaskInfo()
        XCTAssertNotNil(taskInfo)
        XCTAssertEqual(taskInfo?.taskID, 123)
        XCTAssertEqual(taskInfo?.projectID, 456)
    }
    
    func testExtractTaskInfoFromNotes() {
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Description here\n\nKUNA_EVENT: task=789 project=101"
        
        let taskInfo = event.extractTaskInfo()
        XCTAssertNotNil(taskInfo)
        XCTAssertEqual(taskInfo?.taskID, 789)
        XCTAssertEqual(taskInfo?.projectID, 101)
    }
    
    func testExtractTaskInfoPrioritizesURL() {
        let event = EKEvent(eventStore: eventStore)
        event.url = URL(string: "kuna://task/123?project=456")
        event.notes = "KUNA_EVENT: task=789 project=101"
        
        let taskInfo = event.extractTaskInfo()
        XCTAssertNotNil(taskInfo)
        // Should get info from URL, not notes
        XCTAssertEqual(taskInfo?.taskID, 123)
        XCTAssertEqual(taskInfo?.projectID, 456)
    }
    
    func testExtractTaskInfoReturnsNilForNonKunaEvent() {
        let event = EKEvent(eventStore: eventStore)
        event.url = URL(string: "https://example.com")
        event.notes = "Regular notes"
        
        let taskInfo = event.extractTaskInfo()
        XCTAssertNil(taskInfo)
    }
}
