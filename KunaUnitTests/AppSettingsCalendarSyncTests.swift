// KunaTests/AppSettingsCalendarSyncTests.swift
import XCTest
@testable import Kuna

@MainActor
final class AppSettingsCalendarSyncTests: XCTestCase {
    
    var appSettings: AppSettings!
    var originalPrefs: CalendarSyncPrefs!
    
    override func setUp() async throws {
        await super.setUp()
        appSettings = AppSettings.shared
        
        // Save original preferences to restore later
        originalPrefs = appSettings.calendarSyncPrefs
    }
    
    override func tearDown() async throws {
        // Restore original preferences
        appSettings.calendarSyncPrefs = originalPrefs
        await super.tearDown()
    }
    
    // MARK: - Persistence Tests
    
    func testCalendarSyncPrefsDefaultValue() {
        // Reset to default
        appSettings.calendarSyncPrefs = CalendarSyncPrefs()
        
        let prefs = appSettings.calendarSyncPrefs
        XCTAssertFalse(prefs.isEnabled)
        XCTAssertEqual(prefs.mode, .single)
        XCTAssertTrue(prefs.selectedProjectIDs.isEmpty)
        XCTAssertNil(prefs.singleCalendar)
        XCTAssertTrue(prefs.projectCalendars.isEmpty)
        XCTAssertEqual(prefs.version, 1)
    }
    
    func testCalendarSyncPrefsPersistence() {
        // Create test preferences
        let testPrefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: ["1", "2", "3"],
            singleCalendar: nil,
            projectCalendars: [
                "1": KunaCalendarRef(name: "Kuna – Project 1", identifier: "cal-1"),
                "2": KunaCalendarRef(name: "Kuna – Project 2", identifier: "cal-2")
            ],
            version: 1
        )
        
        // Set preferences
        appSettings.calendarSyncPrefs = testPrefs
        
        // Verify they were saved
        let savedPrefs = appSettings.calendarSyncPrefs
        XCTAssertEqual(savedPrefs, testPrefs)
        XCTAssertTrue(savedPrefs.isEnabled)
        XCTAssertEqual(savedPrefs.mode, .perProject)
        XCTAssertEqual(savedPrefs.selectedProjectIDs, ["1", "2", "3"])
        XCTAssertEqual(savedPrefs.projectCalendars.count, 2)
    }
    
    func testCalendarSyncPrefsJSONSerialization() throws {
        // Create test preferences
        let testPrefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .single,
            selectedProjectIDs: ["1", "2"],
            singleCalendar: KunaCalendarRef(name: "Kuna", identifier: "cal-123"),
            projectCalendars: [:],
            version: 1
        )
        
        // Set preferences (this should trigger JSON encoding)
        appSettings.calendarSyncPrefs = testPrefs
        
        // Check if data was stored in UserDefaults
        let data = UserDefaults.standard.data(forKey: "calendarSync.prefs")
        XCTAssertNotNil(data)
        
        // Try to decode the data
        let decoder = JSONDecoder()
        let decodedPrefs = try decoder.decode(CalendarSyncPrefs.self, from: data!)
        XCTAssertEqual(decodedPrefs, testPrefs)
    }
    
    func testCalendarSyncPrefsLoadFromUserDefaults() throws {
        // Create test preferences and encode them manually
        let testPrefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: ["5", "6"],
            singleCalendar: nil,
            projectCalendars: [
                "5": KunaCalendarRef(name: "Project 5", identifier: "cal-5")
            ],
            version: 1
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(testPrefs)
        UserDefaults.standard.set(data, forKey: "calendarSync.prefs")
        
        // Create new AppSettings instance to test loading
        // Note: Since AppSettings is a singleton, we can't test this directly
        // Instead, we test that the current instance has the expected values
        
        // Trigger a reload by setting a different value first
        appSettings.calendarSyncPrefs = CalendarSyncPrefs()
        
        // Then read from UserDefaults manually to verify
        let storedData = UserDefaults.standard.data(forKey: "calendarSync.prefs")
        XCTAssertNotNil(storedData)
        
        let decoder = JSONDecoder()
        let loadedPrefs = try decoder.decode(CalendarSyncPrefs.self, from: storedData!)
        XCTAssertEqual(loadedPrefs, testPrefs)
    }
    
    // MARK: - Integration Tests
    
    func testCalendarSyncPrefsIntegrationWithSettings() {
        // Test that changes to calendar sync preferences integrate properly
        // with other settings
        
        // Initially disabled
        XCTAssertFalse(appSettings.calendarSyncPrefs.isEnabled)
        
        // Enable calendar sync with preferences
        var newPrefs = appSettings.calendarSyncPrefs
        newPrefs.isEnabled = true
        newPrefs.mode = .single
        newPrefs.selectedProjectIDs = ["1"]
        newPrefs.singleCalendar = KunaCalendarRef(name: "Kuna", identifier: "test-cal")
        
        appSettings.calendarSyncPrefs = newPrefs
        
        // Verify integration
        XCTAssertTrue(appSettings.calendarSyncPrefs.isEnabled)
        XCTAssertTrue(appSettings.calendarSyncPrefs.isValid)
    }
    
    func testCalendarSyncPrefsVersionHandling() {
        // Test that version changes are handled properly
        var prefs = CalendarSyncPrefs()
        prefs.version = 2 // Simulate a newer version
        
        appSettings.calendarSyncPrefs = prefs
        
        // Verify version is preserved
        XCTAssertEqual(appSettings.calendarSyncPrefs.version, 2)
    }
    
    // MARK: - Edge Cases
    
    func testCalendarSyncPrefsWithEmptyProjects() {
        let prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: [], // Empty projects
            singleCalendar: nil,
            projectCalendars: [:],
            version: 1
        )
        
        appSettings.calendarSyncPrefs = prefs
        
        // Should be invalid due to no selected projects
        XCTAssertFalse(appSettings.calendarSyncPrefs.isValid)
    }
    
    func testCalendarSyncPrefsWithMismatchedCalendars() {
        let prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: ["1", "2", "3"],
            singleCalendar: nil,
            projectCalendars: [
                "1": KunaCalendarRef(name: "Project 1", identifier: "cal-1")
                // Missing calendars for projects 2 and 3
            ],
            version: 1
        )
        
        appSettings.calendarSyncPrefs = prefs
        
        // Should be invalid due to missing calendars
        XCTAssertFalse(appSettings.calendarSyncPrefs.isValid)
    }
    
    func testCalendarSyncPrefsLargeProjectSet() {
        // Test with a large number of projects
        let projectIDs = Set((1...50).map(String.init))
        let projectCalendars = Dictionary(uniqueKeysWithValues: 
            projectIDs.map { id in
                (id, KunaCalendarRef(name: "Project \(id)", identifier: "cal-\(id)"))
            }
        )
        
        let prefs = CalendarSyncPrefs(
            isEnabled: true,
            mode: .perProject,
            selectedProjectIDs: projectIDs,
            singleCalendar: nil,
            projectCalendars: projectCalendars,
            version: 1
        )
        
        appSettings.calendarSyncPrefs = prefs
        
        // Should handle large sets properly
        XCTAssertTrue(appSettings.calendarSyncPrefs.isValid)
        XCTAssertEqual(appSettings.calendarSyncPrefs.selectedProjectIDs.count, 50)
        XCTAssertEqual(appSettings.calendarSyncPrefs.projectCalendars.count, 50)
    }
}