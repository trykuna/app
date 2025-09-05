// EventKitClientMock.swift
// Test mock for EventKitClient

import EventKit
@testable import Kuna

final class EventKitClientMock: EventKitClient {
    var store: EKEventStore = EKEventStore()
    
    var shouldThrowOnAccess = false
    var mockCalendars: [String: MockCalendar] = [:]
    var mockEvents: [MockEvent] = []
    var saveError: Error?
    var removeError: Error?
    var commitError: Error?
    
    // For testing, we need to handle the case where no EventKit sources exist
    // This commonly happens in iOS Simulator environments
    private var mockSourceAvailable: Bool {
        return store.sources.first(where: { $0.sourceType == .local }) != nil || 
               store.sources.first != nil
    }
    
    struct MockCalendar {
        let identifier: String
        let name: String
        let source: String
    }
    
    struct MockEvent {
        let title: String
        let calendar: String
        let start: Date
        let end: Date
        let url: URL?
    }
    
    func requestAccess() async throws {
        if shouldThrowOnAccess {
            throw EventKitError.accessDenied
        }
    }
    
    func writableSource() -> EKSource? {
        return store.sources.first(where: { $0.sourceType == .local }) ?? store.sources.first
    }
    
    func ensureCalendar(named: String, in source: EKSource) throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = named
        calendar.source = source
        
        // Store in mock registry
        mockCalendars[calendar.calendarIdentifier] = MockCalendar(
            identifier: calendar.calendarIdentifier,
            name: named,
            source: source.title
        )
        
        return calendar
    }
    
    func calendars(for identifiers: [String]) -> [EKCalendar] {
        return identifiers.compactMap { identifier in
            guard mockCalendars[identifier] != nil else { return nil }
            let calendar = EKCalendar(for: .event, eventStore: store)
            return calendar
        }
    }
    
    func events(in calendars: [EKCalendar], start: Date, end: Date) -> [EKEvent] {
        return mockEvents.compactMap { mockEvent in
            guard mockEvent.start >= start && mockEvent.end <= end else { return nil }
            let event = EKEvent(eventStore: store)
            event.title = mockEvent.title
            event.startDate = mockEvent.start
            event.endDate = mockEvent.end
            event.url = mockEvent.url
            return event
        }
    }
    
    func save(event: EKEvent) throws {
        if let error = saveError {
            throw error
        }
        
        // Add to mock events
        if let title = event.title, let start = event.startDate, let end = event.endDate {
            mockEvents.append(MockEvent(
                title: title,
                calendar: event.calendar?.calendarIdentifier ?? "",
                start: start,
                end: end,
                url: event.url
            ))
        }
    }
    
    func remove(event: EKEvent) throws {
        if let error = removeError {
            throw error
        }
        
        // Remove from mock events
        if let title = event.title {
            mockEvents.removeAll { $0.title == title }
        }
    }
    
    func remove(calendar: EKCalendar) throws {
        if let error = removeError {
            throw error
        }
        
        // Remove from mock calendars
        let calendarId = calendar.calendarIdentifier
        mockCalendars = mockCalendars.filter { _, mockCalendar in
            mockCalendar.identifier != calendarId
        }
        
        // Remove all events from this calendar
        mockEvents.removeAll { $0.calendar == calendarId }
    }
    
    func commit() throws {
        if let error = commitError {
            throw error
        }
    }
}