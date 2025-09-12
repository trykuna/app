// KunaUnitTests/TaskSortingServiceTests.swift
import XCTest
@testable import Kuna

final class TaskSortingServiceTests: XCTestCase {
    
    // MARK: - Test Data
    
    var sampleTasks: [VikunjaTask]!
    var now: Date!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        
        now = Date()
        calendar = Calendar.current
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
        let nextMonth = calendar.date(byAdding: .day, value: 30, to: now)!
        let twoMonths = calendar.date(byAdding: .month, value: 2, to: now)!
        
        sampleTasks = [
            // Task 1: High priority, due today
            VikunjaTask.makeTestTask(
                id: 1,
                title: "Alpha Task",
                done: false,
                dueDate: now,
                startDate: now,
                endDate: tomorrow,
                priority: .high
            ),
            // Task 2: No priority, due tomorrow
            VikunjaTask.makeTestTask(
                id: 2,
                title: "Beta Task",
                done: false,
                dueDate: tomorrow,
                startDate: tomorrow,
                endDate: nextWeek,
                priority: .unset
            ),
            // Task 3: Urgent priority, overdue
            VikunjaTask.makeTestTask(
                id: 3,
                title: "Charlie Task",
                done: false,
                dueDate: yesterday,
                startDate: lastWeek,
                endDate: yesterday,
                priority: .urgent
            ),
            // Task 4: Medium priority, no dates
            VikunjaTask.makeTestTask(
                id: 4,
                title: "Delta Task",
                done: false,
                dueDate: nil,
                startDate: nil,
                endDate: nil,
                priority: .medium
            ),
            // Task 5: Low priority, future dates
            VikunjaTask.makeTestTask(
                id: 5,
                title: "Echo Task",
                done: false,
                dueDate: nextMonth,
                startDate: nextWeek,
                endDate: nextMonth,
                priority: .low
            ),
            // Task 6: Do Now priority, no dates
            VikunjaTask.makeTestTask(
                id: 6,
                title: "Foxtrot Task",
                done: false,
                dueDate: nil,
                startDate: nil,
                endDate: nil,
                priority: .doNow
            ),
            // Task 7: Far future task
            VikunjaTask.makeTestTask(
                id: 7,
                title: "Golf Task",
                done: false,
                dueDate: twoMonths,
                startDate: nextMonth,
                endDate: twoMonths,
                priority: .medium
            )
        ]
    }
    
    override func tearDown() {
        sampleTasks = nil
        now = nil
        calendar = nil
        super.tearDown()
    }
    
    // MARK: - Sorting Tests
    
    func testServerOrderSort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .serverOrder)
        XCTAssertEqual(sorted.map(\.id), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(sorted.count, sampleTasks.count)
    }
    
    func testAlphabeticalSort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .alphabetical)
        let expectedTitles = ["Alpha Task", "Beta Task", "Charlie Task", "Delta Task", "Echo Task", "Foxtrot Task", "Golf Task"]
        XCTAssertEqual(sorted.map(\.title), expectedTitles)
    }
    
    func testPrioritySort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .priority)
        
        // Should be sorted by priority value descending (doNow=5, urgent=4, high=3, medium=2, low=1, unset=0)
        let expectedIds = [6, 3, 1, 4, 7, 5, 2] // doNow, urgent, high, medium, medium, low, unset
        XCTAssertEqual(sorted.map(\.id), expectedIds)
        
        // Verify priority order
        XCTAssertEqual(sorted[0].priority, .doNow)
        XCTAssertEqual(sorted[1].priority, .urgent)
        XCTAssertEqual(sorted[2].priority, .high)
        XCTAssertEqual(sorted[3].priority, .medium)
        XCTAssertEqual(sorted[5].priority, .low)
        XCTAssertEqual(sorted[6].priority, .unset)
    }
    
    func testDueDateSort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .dueDate)
        
        // Tasks with due dates should come first (sorted by date), then tasks without due dates
        XCTAssertEqual(sorted[0].id, 3) // Yesterday (overdue)
        XCTAssertEqual(sorted[1].id, 1) // Today
        XCTAssertEqual(sorted[2].id, 2) // Tomorrow
        XCTAssertEqual(sorted[3].id, 5) // Next month
        XCTAssertEqual(sorted[4].id, 7) // Two months
        
        // Tasks without due dates should be last
        XCTAssertNil(sorted[5].dueDate)
        XCTAssertNil(sorted[6].dueDate)
    }
    
    func testStartDateSort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .startDate)
        
        // Tasks with start dates should come first (sorted by date)
        XCTAssertEqual(sorted[0].id, 3) // Last week
        XCTAssertEqual(sorted[1].id, 1) // Today
        XCTAssertEqual(sorted[2].id, 2) // Tomorrow
        XCTAssertEqual(sorted[3].id, 5) // Next week
        XCTAssertEqual(sorted[4].id, 7) // Next month
        
        // Tasks without start dates should be last
        XCTAssertNil(sorted[5].startDate)
        XCTAssertNil(sorted[6].startDate)
    }
    
    func testEndDateSort() {
        let sorted = TaskSortingService.sortTasks(sampleTasks, by: .endDate)
        
        // Tasks with end dates should come first (sorted by date)
        XCTAssertEqual(sorted[0].id, 3) // Yesterday
        XCTAssertEqual(sorted[1].id, 1) // Tomorrow
        XCTAssertEqual(sorted[2].id, 2) // Next week
        XCTAssertEqual(sorted[3].id, 5) // Next month
        XCTAssertEqual(sorted[4].id, 7) // Two months
        
        // Tasks without end dates should be last
        XCTAssertNil(sorted[5].endDate)
        XCTAssertNil(sorted[6].endDate)
    }
    
    // MARK: - Grouping Tests
    
    func testServerOrderGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .serverOrder)
        
        // Server order should return a single group with no label
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].0)
        XCTAssertEqual(groups[0].1.count, 7)
    }
    
    func testAlphabeticalGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .alphabetical)
        
        // Alphabetical should return a single group with no label
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].0)
        XCTAssertEqual(groups[0].1.count, 7)
    }
    
    func testPriorityGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .priority)
        
        // Should have groups for each priority level present, in specific order
        let groupLabels = groups.map { $0.0 }
        XCTAssertEqual(groupLabels, ["Do Now!", "Urgent", "High", "Medium", "Low", "No Priority"])
        
        // Verify task counts in each group
        XCTAssertEqual(groups[0].1.count, 1) // Do Now! - task 6
        XCTAssertEqual(groups[1].1.count, 1) // Urgent - task 3
        XCTAssertEqual(groups[2].1.count, 1) // High - task 1
        XCTAssertEqual(groups[3].1.count, 2) // Medium - tasks 4, 7
        XCTAssertEqual(groups[4].1.count, 1) // Low - task 5
        XCTAssertEqual(groups[5].1.count, 1) // No Priority - task 2
        
        // Verify specific tasks are in correct groups
        XCTAssertEqual(groups[0].1.first?.id, 6) // Do Now!
        XCTAssertEqual(groups[1].1.first?.id, 3) // Urgent
        XCTAssertEqual(groups[2].1.first?.id, 1) // High
        XCTAssertEqual(groups[5].1.first?.id, 2) // No Priority
    }
    
    func testDueDateGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .dueDate)
        
        // Basic test - just verify we have groups
        XCTAssertFalse(groups.isEmpty, "Should have at least one group")
        
        // Get group labels
        let groupLabels = groups.map { $0.0 ?? "nil" }
        
        // We should have some groups for date-based tasks and no-date tasks
        let hasOverdueOrPastGroup = groupLabels.contains("Overdue")
        let hasTodayGroup = groupLabels.contains("Today") 
        let hasTomorrowGroup = groupLabels.contains("Tomorrow")
        let hasNoDueDateGroup = groupLabels.contains("No Due Date")
        
        // At minimum we should have Today, Tomorrow, and No Due Date groups from our sample data
        XCTAssertTrue(hasTodayGroup || hasOverdueOrPastGroup, "Should have today or overdue group")
        XCTAssertTrue(hasTomorrowGroup, "Should have tomorrow group")
        XCTAssertTrue(hasNoDueDateGroup, "Should have no due date group")
    }
    
    func testStartDateGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .startDate)
        
        let groupLabels = groups.map { $0.0 }
        
        // Should have groups based on date buckets
        XCTAssertTrue(groupLabels.contains("Past"))
        XCTAssertTrue(groupLabels.contains("Today"))
        XCTAssertTrue(groupLabels.contains("Tomorrow"))
        XCTAssertTrue(groupLabels.contains("This Week"))
        XCTAssertTrue(groupLabels.contains("This Month"))
        XCTAssertTrue(groupLabels.contains("No Start Date"))
        
        // Verify past tasks
        let pastGroup = groups.first { $0.0 == "Past" }
        XCTAssertNotNil(pastGroup)
        XCTAssertEqual(pastGroup?.1.count, 1)
        XCTAssertEqual(pastGroup?.1.first?.id, 3)
        
        // Verify no start date tasks
        let noStartDateGroup = groups.first { $0.0 == "No Start Date" }
        XCTAssertNotNil(noStartDateGroup)
        XCTAssertEqual(noStartDateGroup?.1.count, 2)
    }
    
    func testEndDateGrouping() {
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .endDate)
        
        let groupLabels = groups.map { $0.0 }
        
        // Should have groups based on date buckets
        XCTAssertTrue(groupLabels.contains("Yesterday"))
        XCTAssertTrue(groupLabels.contains("Tomorrow"))
        XCTAssertTrue(groupLabels.contains("This Week"))
        XCTAssertTrue(groupLabels.contains("This Month"))
        XCTAssertTrue(groupLabels.contains("No End Date"))
        
        // Verify yesterday tasks
        let yesterdayGroup = groups.first { $0.0 == "Yesterday" }
        XCTAssertNotNil(yesterdayGroup)
        XCTAssertEqual(yesterdayGroup?.1.count, 1)
        XCTAssertEqual(yesterdayGroup?.1.first?.id, 3)
        
        // Verify no end date tasks
        let noEndDateGroup = groups.first { $0.0 == "No End Date" }
        XCTAssertNotNil(noEndDateGroup)
        XCTAssertEqual(noEndDateGroup?.1.count, 2)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTaskList() {
        let emptyTasks: [VikunjaTask] = []
        
        // Test sorting empty list
        XCTAssertTrue(TaskSortingService.sortTasks(emptyTasks, by: .alphabetical).isEmpty)
        XCTAssertTrue(TaskSortingService.sortTasks(emptyTasks, by: .priority).isEmpty)
        XCTAssertTrue(TaskSortingService.sortTasks(emptyTasks, by: .dueDate).isEmpty)
        
        // Test grouping empty list
        let serverGroups = TaskSortingService.groupTasksForSorting(emptyTasks, by: .serverOrder)
        XCTAssertEqual(serverGroups.count, 1)
        XCTAssertTrue(serverGroups[0].1.isEmpty)
        
        let alphabeticalGroups = TaskSortingService.groupTasksForSorting(emptyTasks, by: .alphabetical)
        XCTAssertEqual(alphabeticalGroups.count, 1)
        XCTAssertTrue(alphabeticalGroups[0].1.isEmpty)
        
        // Priority grouping should return empty array for empty input
        let priorityGroups = TaskSortingService.groupTasksForSorting(emptyTasks, by: .priority)
        XCTAssertTrue(priorityGroups.isEmpty)
    }
    
    func testSingleTaskList() {
        let singleTask = [sampleTasks[0]]
        
        // Test sorting single task
        XCTAssertEqual(TaskSortingService.sortTasks(singleTask, by: .alphabetical).count, 1)
        XCTAssertEqual(TaskSortingService.sortTasks(singleTask, by: .priority).first?.id, 1)
        
        // Test grouping single task
        let priorityGroups = TaskSortingService.groupTasksForSorting(singleTask, by: .priority)
        XCTAssertEqual(priorityGroups.count, 1)
        XCTAssertEqual(priorityGroups[0].0, "High")
        XCTAssertEqual(priorityGroups[0].1.count, 1)
        
        let dueDateGroups = TaskSortingService.groupTasksForSorting(singleTask, by: .dueDate)
        XCTAssertEqual(dueDateGroups.count, 1)
        XCTAssertEqual(dueDateGroups[0].0, "Today")
        XCTAssertEqual(dueDateGroups[0].1.count, 1)
    }
    
    func testAllTasksSamePriority() {
        let samePriorityTasks = sampleTasks.map { task in
            VikunjaTask.makeTestTask(
                id: task.id,
                title: task.title,
                done: task.done,
                dueDate: task.dueDate,
                startDate: task.startDate,
                endDate: task.endDate,
                priority: .medium
            )
        }
        
        let groups = TaskSortingService.groupTasksForSorting(samePriorityTasks, by: .priority)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].0, "Medium")
        XCTAssertEqual(groups[0].1.count, 7)
    }
    
    func testAllTasksNoDates() {
        let noDateTasks = sampleTasks.map { task in
            VikunjaTask.makeTestTask(
                id: task.id,
                title: task.title,
                done: task.done,
                dueDate: nil,
                startDate: nil,
                endDate: nil,
                priority: task.priority
            )
        }
        
        let dueDateGroups = TaskSortingService.groupTasksForSorting(noDateTasks, by: .dueDate)
        XCTAssertEqual(dueDateGroups.count, 1)
        XCTAssertEqual(dueDateGroups[0].0, "No Due Date")
        XCTAssertEqual(dueDateGroups[0].1.count, 7)
        
        let startDateGroups = TaskSortingService.groupTasksForSorting(noDateTasks, by: .startDate)
        XCTAssertEqual(startDateGroups.count, 1)
        XCTAssertEqual(startDateGroups[0].0, "No Start Date")
        XCTAssertEqual(startDateGroups[0].1.count, 7)
    }
    
    func testGroupOrdering() {
        // Test that groups appear in the correct order for date-based sorting
        let groups = TaskSortingService.groupTasksForSorting(sampleTasks, by: .dueDate)
        let groupLabels = groups.map { $0.0 }
        
        // Overdue should come before Today
        if let overdueIndex = groupLabels.firstIndex(of: "Overdue"),
           let todayIndex = groupLabels.firstIndex(of: "Today") {
            XCTAssertLessThan(overdueIndex, todayIndex)
        }
        
        // Today should come before Tomorrow
        if let todayIndex = groupLabels.firstIndex(of: "Today"),
           let tomorrowIndex = groupLabels.firstIndex(of: "Tomorrow") {
            XCTAssertLessThan(todayIndex, tomorrowIndex)
        }
        
        // No Due Date should be after date groups
        if let noDueDateIndex = groupLabels.firstIndex(of: "No Due Date"),
           let todayIndex = groupLabels.firstIndex(of: "Today") {
            XCTAssertGreaterThan(noDueDateIndex, todayIndex)
        }
    }
}