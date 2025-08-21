import XCTest
@testable import Kuna
import EventKit
import Foundation

final class TaskEventMapperTests: XCTestCase {
    
    private var eventStore: EKEventStore!
    private var calendar: EKCalendar!
    private var isEventKitAvailable = false
    
    override func setUp() {
        super.setUp()
        
        // Reset availability flag
        isEventKitAvailable = false
        
        // Create event store
        eventStore = EKEventStore()
        
        // Check if we have any calendars or sources available
        // This is a good indicator of whether EventKit is functional
        guard !eventStore.sources.isEmpty else {
            print("No EventKit sources available - tests will be skipped")
            return
        }
        
        // For testing, we need a calendar. Try different approaches:
        // 1. Use the default calendar if available
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            calendar = defaultCalendar
            isEventKitAvailable = true
            return
        }
        
        // 2. Try to find any existing calendar we can use
        let calendars = eventStore.calendars(for: .event)
        if let existingCalendar = calendars.first(where: { $0.allowsContentModifications }) {
            calendar = existingCalendar
            isEventKitAvailable = true
            return
        }
        
        // 3. As a last resort, create a test calendar
        // Note: This might not work without proper permissions
        calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "Kuna Test Calendar"
        
        // Find the first available source
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
            isEventKitAvailable = true
        } else if let anySource = eventStore.sources.first {
            calendar.source = anySource
            isEventKitAvailable = true
        }
        
        if calendar.source != nil {
            calendar.cgColor = UIColor.systemBlue.cgColor
        }
    }
    
    override func tearDown() {
        eventStore = nil
        calendar = nil
        super.tearDown()
    }
    
    // MARK: - CalendarSyncTask Creation Tests
    
    func testCalendarSyncTaskFromVikunjaTask() {
        let vikunjaTask = createSampleVikunjaTask()
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: vikunjaTask.projectId ?? 1, projectTitle: "Test Project")
        
        XCTAssertEqual(syncTask.id, String(vikunjaTask.id))
        XCTAssertEqual(syncTask.title, vikunjaTask.title)
        XCTAssertEqual(syncTask.dueDate, vikunjaTask.dueDate)
        XCTAssertEqual(syncTask.projectId, vikunjaTask.projectId ?? 1)
        XCTAssertEqual(syncTask.notes, vikunjaTask.description)
        XCTAssertEqual(syncTask.reminders.count, vikunjaTask.reminders?.count ?? 0)
    }
    
    func testCalendarSyncTaskWithReminders() {
        let dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        let reminders = [
            Reminder(reminder: dueDate.addingTimeInterval(-900)), // 15 min before
            Reminder(reminder: dueDate.addingTimeInterval(-300))   // 5 min before
        ]
        
        let vikunjaTask = createVikunjaTask(
            id: 1,
            title: "Task with reminders",
            description: "Test description",
            dueDate: dueDate,
            reminders: reminders,
            projectId: 1
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        XCTAssertEqual(syncTask.reminders.count, 2)
        
        // Test reminder calculations
        let firstReminder = syncTask.reminders[0]
        XCTAssertEqual(firstReminder.relativeSeconds, -900, accuracy: 1.0)
        
        let secondReminder = syncTask.reminders[1]
        XCTAssertEqual(secondReminder.relativeSeconds, -300, accuracy: 1.0)
    }
    
    func testCalendarSyncTaskAllDayDetection() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Test all-day task (due at start of day)
        let allDayTask = createVikunjaTask(
            id: 1,
            title: "All day task",
            dueDate: today,
            projectId: 1
        )
        
        let allDaySyncTask = CalendarSyncTask(from: allDayTask, projectId: 1, projectTitle: "Test Project")
        XCTAssertTrue(allDaySyncTask.isAllDay)
        
        // Test timed task (due at specific time)
        let timedDue = today.addingTimeInterval(14 * 3600) // 2 PM
        let timedTask = createVikunjaTask(
            id: 2,
            title: "Timed task",
            dueDate: timedDue,
            projectId: 1
        )
        
        let timedSyncTask = CalendarSyncTask(from: timedTask, projectId: 1, projectTitle: "Test Project")
        XCTAssertFalse(timedSyncTask.isAllDay)
    }
    
    // MARK: - Task to Event Mapping Tests
    
    func testApplyTaskToEventAllDay() {
        // Skip if EventKit is not available
        guard isEventKitAvailable else {
            XCTSkip("EventKit not available in test environment")
            return
        }
        
        // Create test data - use a fixed date to avoid timezone issues
        let cal = Calendar.current
        let dateComponents = DateComponents(year: 2025, month: 1, day: 15)
        let today = cal.date(from: dateComponents) ?? Date()
        let startOfToday = cal.startOfDay(for: today)
        
        let vikunjaTask = createVikunjaTask(
            id: 1,
            title: "All Day Event",
            description: "Test notes",
            dueDate: startOfToday,
            projectId: 1
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        
        // Create test event
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        
        TaskEventMapper.apply(task: syncTask, to: event)
        
        XCTAssertEqual(event.title, "All Day Event")
        XCTAssertTrue(event.isAllDay)
        
        // For all-day events, just verify that:
        // 1. Start date is the same day as the due date
        // 2. End date is at least the next day
        if let startDate = event.startDate, let endDate = event.endDate {
            // Check that start is on the correct day
            let startDay = cal.dateComponents([.year, .month, .day], from: startDate)
            let expectedDay = cal.dateComponents([.year, .month, .day], from: startOfToday)
            XCTAssertEqual(startDay.year, expectedDay.year)
            XCTAssertEqual(startDay.month, expectedDay.month)
            XCTAssertEqual(startDay.day, expectedDay.day)
            
            // Check that the event spans at least one day
            let duration = endDate.timeIntervalSince(startDate)
            XCTAssertGreaterThanOrEqual(duration, 24 * 60 * 60 - 60, // Allow for 1 minute tolerance
                                        "All-day event should span at least 24 hours")
        } else {
            XCTFail("Event dates should not be nil")
        }
    }
    
    func testApplyTaskToEventTimed() {
        // Skip if EventKit is not available
        guard isEventKitAvailable else {
            XCTSkip("EventKit not available in test environment")
            return
        }
        
        let dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        
        let vikunjaTask = createVikunjaTask(
            id: 2,
            title: "Timed Event",
            description: "Test notes",
            dueDate: dueDate,
            projectId: 1
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        
        TaskEventMapper.apply(task: syncTask, to: event)
        
        XCTAssertEqual(event.title, "Timed Event")
        XCTAssertFalse(event.isAllDay)
        
        // Check end date (should be the due date)
        if let endDate = event.endDate {
            XCTAssertEqual(endDate.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 1.0)
        } else {
            XCTFail("Event end date should not be nil")
        }
        
        // Timed events should start 1 hour before due time
        let expectedStart = dueDate.addingTimeInterval(-3600)
        if let startDate = event.startDate {
            XCTAssertEqual(startDate.timeIntervalSince1970, expectedStart.timeIntervalSince1970, accuracy: 1.0)
        } else {
            XCTFail("Event start date should not be nil")
        }
    }
    
    func testApplyTaskToEventWithReminders() {
        // Skip if EventKit is not available
        guard isEventKitAvailable else {
            XCTSkip("EventKit not available in test environment")
            return
        }
        
        let dueDate = Date().addingTimeInterval(3600)
        let reminderDates = [
            dueDate.addingTimeInterval(-900), // 15 min before due
            dueDate.addingTimeInterval(-300)  // 5 min before due
        ]
        let reminders = reminderDates.map { date in
            Reminder(reminder: date)
        }
        
        let vikunjaTask = createVikunjaTask(
            id: 3,
            title: "Event with Reminders",
            description: "Test notes",
            dueDate: dueDate,
            reminders: reminders,
            projectId: 1
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        
        TaskEventMapper.apply(task: syncTask, to: event)
        
        XCTAssertEqual(event.alarms?.count, 2)
        
        // Check reminder offsets
        // Note: For timed events, TaskEventMapper adds 3600 to the offset since events start 1 hour before due
        let sortedAlarms = event.alarms?.sorted { $0.relativeOffset < $1.relativeOffset } ?? []
        XCTAssertEqual(sortedAlarms[0].relativeOffset, 2700, accuracy: 1.0)  // -900 + 3600 = 2700
        XCTAssertEqual(sortedAlarms[1].relativeOffset, 3300, accuracy: 1.0)  // -300 + 3600 = 3300
    }
    
    func testApplyTaskToEventAllDayReminders() {
        let today = Calendar.current.startOfDay(for: Date())
        let reminderDate = today.addingTimeInterval(-1800) // 30 min before
        let reminders = [Reminder(reminder: reminderDate)]
        
        let vikunjaTask = createVikunjaTask(
            id: 4,
            title: "All Day with Reminder",
            description: "Test notes",
            dueDate: today,
            reminders: reminders,
            projectId: 1
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        
        let event = EKEvent(eventStore: eventStore)
        if calendar != nil {
            event.calendar = self.calendar
        }
        TaskEventMapper.apply(task: syncTask, to: event)
        
        XCTAssertEqual(event.alarms?.count, 1)
        
        // For all-day events, reminder offset is used as-is (no +3600 adjustment)
        let alarm = event.alarms?.first
        XCTAssertEqual(alarm?.relativeOffset ?? 0, -1800, accuracy: 1.0)
    }
    
    func testApplyTaskToEventURL() {
        let vikunjaTask = createVikunjaTask(
            id: 42,
            title: "Test Task",
            description: "Test notes",
            dueDate: Date(),
            projectId: 123
        )
        
        let syncTask = CalendarSyncTask(from: vikunjaTask, projectId: 123, projectTitle: "Test Project")
        
        let event = EKEvent(eventStore: eventStore)
        if calendar != nil {
            event.calendar = self.calendar
        }
        TaskEventMapper.apply(task: syncTask, to: event)
        
        XCTAssertNotNil(event.url)
        XCTAssertEqual(event.url?.scheme, SyncConst.scheme)
        XCTAssertEqual(event.url?.host, SyncConst.hostTask)
        XCTAssertEqual(event.url?.path, "/42")
        
        // Check query parameter for project
        let components = URLComponents(url: event.url!, resolvingAgainstBaseURL: false)
        let projectParam = components?.queryItems?.first { $0.name == "project" }
        XCTAssertEqual(projectParam?.value, "123")
    }
    
    // MARK: - Event Signature Tests
    
    func testEventSignatureMake() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)
        let alarms = [EKAlarm(relativeOffset: -900)]
        
        let signature = EventSignature.make(
            title: "Test Event",
            start: startDate,
            end: endDate,
            isAllDay: false,
            alarms: alarms,
            notes: "Test notes"
        )
        
        XCTAssertNotNil(signature)
        XCTAssertFalse(signature.isEmpty)
        
        // Same inputs should produce same signature
        let signature2 = EventSignature.make(
            title: "Test Event",
            start: startDate,
            end: endDate,
            isAllDay: false,
            alarms: alarms,
            notes: "Test notes"
        )
        
        XCTAssertEqual(signature, signature2)
    }
    
    func testEventSignatureConsistency() {
        let date = Date()
        
        // Different inputs should produce different signatures
        let sig1 = EventSignature.make(title: "Event 1", start: date, end: date.addingTimeInterval(3600), isAllDay: false, alarms: [], notes: nil)
        let sig2 = EventSignature.make(title: "Event 2", start: date, end: date.addingTimeInterval(3600), isAllDay: false, alarms: [], notes: nil)
        let sig3 = EventSignature.make(title: "Event 1", start: date, end: date.addingTimeInterval(7200), isAllDay: false, alarms: [], notes: nil)
        
        XCTAssertNotEqual(sig1, sig2, "Different titles should produce different signatures")
        XCTAssertNotEqual(sig1, sig3, "Different end dates should produce different signatures")
    }
    
    // MARK: - RelativeReminder Tests
    
    func testRelativeReminderFromReminder() {
        let dueDate = Date().addingTimeInterval(3600)
        let reminderDate = dueDate.addingTimeInterval(-900) // 15 min before due
        
        let reminder = Reminder(reminder: reminderDate)
        let relativeSeconds = reminder.reminder.timeIntervalSince(dueDate)
        let relativeReminder = RelativeReminder(relativeSeconds: relativeSeconds)
        
        XCTAssertEqual(relativeReminder.relativeSeconds, -900, accuracy: 1.0)
    }
    
    func testRelativeReminderEdgeCases() {
        let dueDate = Date().addingTimeInterval(3600)
        
        // Reminder after due date (should be positive relative time)
        let lateReminder = Reminder(reminder: dueDate.addingTimeInterval(300))
        let lateRelativeSeconds = lateReminder.reminder.timeIntervalSince(dueDate)
        let lateRelativeReminder = RelativeReminder(relativeSeconds: lateRelativeSeconds)
        XCTAssertEqual(lateRelativeReminder.relativeSeconds, 300, accuracy: 1.0)
        
        // Reminder exactly at due date
        let exactReminder = Reminder(reminder: dueDate)
        let exactRelativeSeconds = exactReminder.reminder.timeIntervalSince(dueDate)
        let exactRelativeReminder = RelativeReminder(relativeSeconds: exactRelativeSeconds)
        XCTAssertEqual(exactRelativeReminder.relativeSeconds, 0, accuracy: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleVikunjaTask() -> VikunjaTask {
        return createVikunjaTask(
            id: 1,
            title: "Sample Task",
            description: "A sample task for testing",
            dueDate: Date().addingTimeInterval(3600),
            projectId: 1
        )
    }
    
    private func createVikunjaTask(
        id: Int,
        title: String,
        description: String? = nil,
        done: Bool = false,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        labels: [Kuna.Label]? = nil,
        reminders: [Reminder]? = nil,
        priority: TaskPriority = .medium,
        percentDone: Double = 0.0,
        hexColor: String? = nil,
        repeatAfter: Int? = nil,
        repeatMode: RepeatMode = .afterAmount,
        assignees: [VikunjaUser]? = nil,
        createdBy: VikunjaUser? = nil,
        projectId: Int? = nil,
        isFavorite: Bool = false,
        attachments: [TaskAttachment]? = nil,
        commentCount: Int? = nil,
        updatedAt: Date? = nil,
        relations: [TaskRelation]? = nil
    ) -> VikunjaTask {
        return VikunjaTask(
            id: id,
            title: title,
            description: description,
            done: done,
            dueDate: dueDate,
            startDate: startDate,
            endDate: endDate,
            labels: labels,
            reminders: reminders,
            priority: priority,
            percentDone: percentDone,
            hexColor: hexColor,
            repeatAfter: repeatAfter,
            repeatMode: repeatMode,
            assignees: assignees,
            createdBy: createdBy,
            projectId: projectId,
            isFavorite: isFavorite,
            attachments: attachments,
            commentCount: commentCount,
            updatedAt: updatedAt,
            relations: relations
        )
    }
}

// MARK: - Test Data Structures

private struct TestSyncTask {
    let id: Int
    let title: String
    let dueDate: Date
    let projectId: Int
    let notes: String?
    let reminders: [RelativeReminder]
    let isAllDay: Bool
}

// MARK: - Performance Tests

extension TaskEventMapperTests {
    
    func testTaskMappingPerformance() {
        let tasks = (1...100).map { i in
            let vikunjaTask = createVikunjaTask(
                id: i,
                title: "Task \(i)",
                description: "Notes for task \(i)",
                dueDate: Date().addingTimeInterval(TimeInterval(i * 3600)),
                reminders: [Reminder(reminder: Date().addingTimeInterval(TimeInterval(i * 3600 - 900)))],
                projectId: 1
            )
            return CalendarSyncTask(from: vikunjaTask, projectId: 1, projectTitle: "Test Project")
        }
        
        measure {
            for task in tasks {
                let event = EKEvent(eventStore: eventStore)
                TaskEventMapper.apply(task: task, to: event)
            }
        }
    }
    
    func testSignatureGenerationPerformance() {
        let baseDate = Date()
        let alarms = [EKAlarm(relativeOffset: -900)]
        
        measure {
            for i in 1...1000 {
                _ = EventSignature.make(
                    title: "Event \(i)",
                    start: baseDate.addingTimeInterval(TimeInterval(i)),
                    end: baseDate.addingTimeInterval(TimeInterval(i + 3600)),
                    isAllDay: false,
                    alarms: alarms,
                    notes: "Notes \(i)"
                )
            }
        }
    }
}