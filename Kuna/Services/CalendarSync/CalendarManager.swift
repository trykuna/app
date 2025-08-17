// Services/CalendarSync/CalendarManager.swift
import Foundation
import EventKit
import UIKit

final class CalendarManager {
    let store = EKEventStore()
    
    // MARK: - Calendar Management
    
    func ensureKunaCalendar() throws -> EKCalendar {
        // Check if Kuna calendar already exists
        if let existing = store.calendars(for: .event).first(where: { $0.title == SyncConst.calendarTitle }) {
            return existing
        }
        
        // Create new Kuna calendar
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = SyncConst.calendarTitle
        
        // Set calendar source (prefer default, fallback to local)
        if let defaultSource = store.defaultCalendarForNewEvents?.source {
            cal.source = defaultSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            cal.source = localSource
        } else {
            throw CalendarError.noAvailableSource
        }
        
        cal.cgColor = UIColor.systemBlue.cgColor
        
        try store.saveCalendar(cal, commit: true)
        return cal
    }
    
    func predicate(in cal: EKCalendar, window: DateInterval) -> NSPredicate {
        return store.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: [cal]
        )
    }
    
    // MARK: - Event Operations
    
    func events(in calendar: EKCalendar, window: DateInterval) -> [EKEvent] {
        let predicate = self.predicate(in: calendar, window: window)
        return store.events(matching: predicate)
    }
    
    func event(withIdentifier identifier: String) -> EKEvent? {
        return store.event(withIdentifier: identifier)
    }
    
    func save(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try store.save(event, span: span)
    }
    
    func remove(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try store.remove(event, span: span)
    }
    
    // MARK: - Task ID Extraction
    
    func taskId(from event: EKEvent) -> String? {
        guard let url = event.url,
              url.scheme == SyncConst.scheme,
              url.host == SyncConst.hostTask else {
            return nil
        }
        return url.lastPathComponent
    }
    
    // MARK: - Event Finding
    
    func findEvent(byTaskId taskId: String, in calendar: EKCalendar, window: DateInterval, idMap: IdMap) -> EKEvent? {
        // First try using the ID map
        if let eventId = idMap.taskIdToEventId[taskId],
           let event = event(withIdentifier: eventId) {
            return event
        }
        
        // Fallback: scan calendar for URL match
        let events = self.events(in: calendar, window: window)
        return events.first { event in
            self.taskId(from: event) == taskId
        }
    }
    
    // MARK: - Events Changed Since
    
    func eventsChangedSince(_ date: Date?, in calendar: EKCalendar, within window: DateInterval) -> [EKEvent] {
        let events = self.events(in: calendar, window: window)
        
        guard let sinceDate = date else {
            // If no date provided, return all events
            return events
        }
        
        return events.filter { event in
            // Check if event was modified after the given date
            if let lastModified = event.lastModifiedDate {
                return lastModified > sinceDate
            }
            // If no lastModifiedDate, include it to be safe
            return true
        }
    }
    
    // MARK: - Authorization
    
    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    var authorizationStatus: EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
    
    var hasAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
}

// MARK: - Calendar Errors

enum CalendarError: LocalizedError {
    case noAvailableSource
    case calendarNotFound
    case accessDenied
    case eventNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAvailableSource:
            return "No available calendar source found"
        case .calendarNotFound:
            return "Kuna calendar not found"
        case .accessDenied:
            return "Calendar access denied"
        case .eventNotFound:
            return "Event not found"
        }
    }
}
