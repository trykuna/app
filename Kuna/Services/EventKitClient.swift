// Services/EventKitClient.swift
import Foundation
import EventKit
import UIKit

// MARK: - EventKitClient Protocol

protocol EventKitClient {
    func requestAccess() async throws
    func writableSource() -> EKSource?
    func ensureCalendar(named: String, in source: EKSource) throws -> EKCalendar
    func calendars(for identifiers: [String]) -> [EKCalendar]
    func events(in calendars: [EKCalendar], start: Date, end: Date) -> [EKEvent]
    func save(event: EKEvent) throws
    func remove(event: EKEvent) throws
    func remove(calendar: EKCalendar) throws
    func commit() throws
    var store: EKEventStore { get }
}

// MARK: - Live Implementation

final class EventKitClientLive: EventKitClient {
    let store = EKEventStore()
    
    func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        if !granted {
            throw EventKitError.accessDenied
        }
    }
    
    func writableSource() -> EKSource? {
        // Preferred order: iCloud CalDAV, Local, defaultCalendarForNewEvents?.source
        let sources = store.sources
        
        // 1. Try iCloud CalDAV
        if let iCloudSource = sources.first(where: { 
            $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("icloud") 
        }) {
            return iCloudSource
        }
        
        // 2. Try Local
        if let localSource = sources.first(where: { $0.sourceType == .local }) {
            return localSource
        }
        
        // 3. Fallback to default calendar's source
        return store.defaultCalendarForNewEvents?.source
    }
    
    func ensureCalendar(named: String, in source: EKSource) throws -> EKCalendar {
        // First check if calendar already exists
        let existingCalendars = store.calendars(for: .event)
        if let existing = existingCalendars.first(where: { $0.title == named && $0.source == source }) {
            return existing
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = named
        calendar.source = source
        
        // Set a distinguishable color
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
    
    func calendars(for identifiers: [String]) -> [EKCalendar] {
        let allCalendars = store.calendars(for: .event)
        return allCalendars.filter { identifiers.contains($0.calendarIdentifier) }
    }
    
    func events(in calendars: [EKCalendar], start: Date, end: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }
    
    func save(event: EKEvent) throws {
        try store.save(event, span: .thisEvent, commit: false)
    }
    
    func remove(event: EKEvent) throws {
        try store.remove(event, span: .thisEvent, commit: false)
    }
    
    func remove(calendar: EKCalendar) throws {
        try store.removeCalendar(calendar, commit: false)
    }
    
    func commit() throws {
        try store.commit()
    }
}

// MARK: - Mock Implementation for Testing

final class EventKitClientMock: EventKitClient {
    var store: EKEventStore = EKEventStore()
    
    var shouldThrowOnAccess = false
    var mockCalendars: [String: MockCalendar] = [:]
    var mockEvents: [MockEvent] = []
    var saveError: Error?
    var removeError: Error?
    var commitError: Error?
    
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
        // Return a mock source for testing
        return store.sources.first ?? store.defaultCalendarForNewEvents?.source
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

// MARK: - EventKit Errors

enum EventKitError: LocalizedError {
    case accessDenied
    case calendarNotFound
    case calendarCreationFailed
    case saveFailed
    case commitFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Please enable calendar access in Settings."
        case .calendarNotFound:
            return "The required calendar could not be found."
        case .calendarCreationFailed:
            return "Failed to create calendar."
        case .saveFailed:
            return "Failed to save calendar event."
        case .commitFailed:
            return "Failed to commit calendar changes."
        }
    }
}

// MARK: - Event Tagging Utilities

extension EKEvent {
    private static let kunaEventMarker = "KUNA_EVENT:"
    
    var isKunaEvent: Bool {
        // Check URL scheme
        if let url = url, url.scheme == "kuna" {
            return true
        }
        
        // Check notes for marker
        if let notes = notes, notes.contains(Self.kunaEventMarker) {
            return true
        }
        
        return false
    }
    
    func setKunaTaskInfo(taskID: Int, projectID: Int) {
        // Set URL
        url = URL(string: "kuna://task/\(taskID)?project=\(projectID)")
        
        // Add marker to notes
        let marker = "\(Self.kunaEventMarker) task=\(taskID) project=\(projectID)"
        if let existingNotes = notes, !existingNotes.isEmpty {
            notes = "\(existingNotes)\n\n\(marker)"
        } else {
            notes = marker
        }
    }
    
    func extractTaskInfo() -> (taskID: Int, projectID: Int)? {
        // Try URL first
        if let url = url, url.scheme == "kuna", url.host == "task" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 2, let taskID = Int(pathComponents[1]) {
                let projectID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "project" })?
                    .value.flatMap(Int.init) ?? 0
                return (taskID: taskID, projectID: projectID)
            }
        }
        
        // Try notes
        if let notes = notes, let range = notes.range(of: Self.kunaEventMarker) {
            let markerLine = String(notes[range.lowerBound...])
                .components(separatedBy: .newlines).first ?? ""
            
            let components = markerLine.components(separatedBy: " ")
            var taskID: Int?
            var projectID: Int?
            
            for component in components {
                if component.hasPrefix("task="), let id = Int(component.dropFirst(5)) {
                    taskID = id
                } else if component.hasPrefix("project="), let id = Int(component.dropFirst(8)) {
                    projectID = id
                }
            }
            
            if let taskID = taskID, let projectID = projectID {
                return (taskID: taskID, projectID: projectID)
            }
        }
        
        return nil
    }
}
