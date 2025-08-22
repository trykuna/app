// KunaTests/CalendarSyncModelsTests.swift
import XCTest
@testable import Kuna

final class CalendarSyncModelsTests: XCTestCase {
    
    // MARK: - CalendarSyncMode Tests
    
    func testCalendarSyncModeDisplayNames() {
        XCTAssertEqual(CalendarSyncMode.single.displayName, "Single Calendar")
        XCTAssertEqual(CalendarSyncMode.perProject.displayName, "Calendar per Project")
    }
    
    func testCalendarSyncModeDescriptions() {
        XCTAssertEqual(CalendarSyncMode.single.description, "All tasks in one \"Kuna\" calendar")
        XCTAssertEqual(CalendarSyncMode.perProject.description, "Separate calendar for each project")
    }
    
    func testCalendarSyncModeCodable() throws {
        // Test encoding
        let singleMode = CalendarSyncMode.single
        let singleData = try JSONEncoder().encode(singleMode)
        let singleDecoded = try JSONDecoder().decode(CalendarSyncMode.self, from: singleData)
        XCTAssertEqual(singleMode, singleDecoded)
        
        let perProjectMode = CalendarSyncMode.perProject
        let perProjectData = try JSONEncoder().encode(perProjectMode)
        let perProjectDecoded = try JSONDecoder().decode(CalendarSyncMode.self, from: perProjectData)
        XCTAssertEqual(perProjectMode, perProjectDecoded)
    }
    
    // MARK: - KunaCalendarRef Tests
    
    func testKunaCalendarRefCreation() {
        let calendarRef = KunaCalendarRef(name: "Test Calendar", identifier: "test-123")
        XCTAssertEqual(calendarRef.name, "Test Calendar")
        XCTAssertEqual(calendarRef.identifier, "test-123")
    }
    
    func testKunaCalendarRefCodable() throws {
        let original = KunaCalendarRef(name: "Kuna", identifier: "cal-456")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KunaCalendarRef.self, from: data)
        
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.identifier, decoded.identifier)
    }
    
    func testKunaCalendarRefHashable() {
        let ref1 = KunaCalendarRef(name: "Calendar", identifier: "123")
        let ref2 = KunaCalendarRef(name: "Calendar", identifier: "123")
        let ref3 = KunaCalendarRef(name: "Different", identifier: "456")
        
        XCTAssertEqual(ref1, ref2)
        XCTAssertNotEqual(ref1, ref3)
        
        let set: Set<KunaCalendarRef> = [ref1, ref2, ref3]
        XCTAssertEqual(set.count, 2) // ref1 and ref2 should be treated as the same
    }
    
    // MARK: - CalendarSyncPrefs Tests
    
    func testCalendarSyncPrefsDefaultInit() {
        let prefs = CalendarSyncPrefs()
        
        XCTAssertFalse(prefs.isEnabled)
        XCTAssertEqual(prefs.mode, .single)
        XCTAssertTrue(prefs.selectedProjectIDs.isEmpty)
        XCTAssertNil(prefs.singleCalendar)
        XCTAssertTrue(prefs.projectCalendars.isEmpty)
        XCTAssertEqual(prefs.version, 1)
    }
    
    func testCalendarSyncPrefsCustomInit() {
        let projectIDs: Set<String> = ["1", "2", "3"]
        let singleCalendar = KunaCalendarRef(name: "Kuna", identifier: "cal-123")
        let projectCalendars = [
            "1": KunaCalendarRef(name: "Kuna – Project 1", identifier: "cal-proj-1"),
            "2": KunaCalendarRef(name: "Kuna – Project 2", identifier: "cal-proj-2")
        ]
        
        let prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: projectIDs,
            singleCalendar: singleCalendar,
            projectCalendars: projectCalendars,
            version: 2
        )
        
        XCTAssertTrue(prefs.isEnabled)
        XCTAssertEqual(prefs.mode, .perProject)
        XCTAssertEqual(prefs.selectedProjectIDs, projectIDs)
        XCTAssertEqual(prefs.singleCalendar, singleCalendar)
        XCTAssertEqual(prefs.projectCalendars.count, 2)
        XCTAssertEqual(prefs.version, 2)
    }
    
    func testCalendarSyncPrefsValidation() {
        // Single mode should be valid with singleCalendar
        var prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .single,
            selectedProjectIDs: ["1"],
            singleCalendar: KunaCalendarRef(name: "Kuna", identifier: "cal-123"),
            projectCalendars: [:],
            version: 1
        )
        XCTAssertTrue(prefs.isValid)
        
        // Single mode should be invalid without singleCalendar
        prefs.singleCalendar = nil
        XCTAssertFalse(prefs.isValid)
        
        // Per-project mode should be valid with matching calendars
        prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: ["1", "2"],
            singleCalendar: nil,
            projectCalendars: [
                "1": KunaCalendarRef(name: "Project 1", identifier: "cal-1"),
                "2": KunaCalendarRef(name: "Project 2", identifier: "cal-2")
            ],
            version: 1
        )
        XCTAssertTrue(prefs.isValid)
        
        // Per-project mode should be invalid with missing calendar
        prefs.projectCalendars.removeValue(forKey: "2")
        XCTAssertFalse(prefs.isValid)
        
        // Per-project mode should be invalid with no selected projects
        prefs.selectedProjectIDs = []
        XCTAssertFalse(prefs.isValid)
    }
    
    func testCalendarSyncPrefsCodable() throws {
        let original = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: ["1", "2"],
            singleCalendar: nil,
            projectCalendars: [
                "1": KunaCalendarRef(name: "Project 1", identifier: "cal-1")
            ],
            version: 1
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CalendarSyncPrefs.self, from: data)
        
        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - DisableDisposition Tests
    
    func testDisableDispositionDisplayNames() {
        XCTAssertEqual(DisableDisposition.keepEverything.displayName, "Keep Everything")
        XCTAssertEqual(DisableDisposition.removeKunaEvents.displayName, "Remove Kuna Events")
        XCTAssertEqual(DisableDisposition.archiveCalendars.displayName, "Archive Calendars")
    }
    
    func testDisableDispositionDescriptions() {
        XCTAssertEqual(DisableDisposition.keepEverything.description, "Keep calendars and events (recommended)")
        XCTAssertEqual(DisableDisposition.removeKunaEvents.description, "Remove Kuna events only, keep calendars")
        XCTAssertEqual(DisableDisposition.archiveCalendars.description, "Rename calendars to archived and stop syncing")
    }
    
    func testDisableDispositionAllCases() {
        let allCases = DisableDisposition.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.keepEverything))
        XCTAssertTrue(allCases.contains(.removeKunaEvents))
        XCTAssertTrue(allCases.contains(.archiveCalendars))
    }
}