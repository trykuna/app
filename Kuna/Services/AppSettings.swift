// Services/AppSettings.swift
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var showDefaultColorBalls: Bool {
        didSet {
            UserDefaults.standard.set(showDefaultColorBalls, forKey: "showDefaultColorBalls")
        }
    }
    
    @Published var defaultSortOption: TaskSortOption {
        didSet {
            UserDefaults.standard.set(defaultSortOption.rawValue, forKey: "defaultSortOption")
        }
    }

    @Published var calendarSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(calendarSyncEnabled, forKey: "calendarSyncEnabled")
            CalendarSyncService.shared.setCalendarSyncEnabled(calendarSyncEnabled)
        }
    }

    @Published var autoSyncNewTasks: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncNewTasks, forKey: "autoSyncNewTasks")
        }
    }

    @Published var syncTasksWithDatesOnly: Bool {
        didSet {
            UserDefaults.standard.set(syncTasksWithDatesOnly, forKey: "syncTasksWithDatesOnly")
        }
    }

    // Display Options
    @Published var showAttachmentIcons: Bool {
        didSet {
            UserDefaults.standard.set(showAttachmentIcons, forKey: "showAttachmentIcons")
        }
    }

    @Published var showCommentCounts: Bool {
        didSet {
            UserDefaults.standard.set(showCommentCounts, forKey: "showCommentCounts")
        }
    }

    @Published var showPriorityIndicators: Bool {
        didSet {
            UserDefaults.standard.set(showPriorityIndicators, forKey: "showPriorityIndicators")
        }
    }

    @Published var showTaskColors: Bool {
        didSet {
            UserDefaults.standard.set(showTaskColors, forKey: "showTaskColors")
        }
    }

    // Celebration
    @Published var celebrateCompletionConfetti: Bool {
        didSet { UserDefaults.standard.set(celebrateCompletionConfetti, forKey: "celebrateCompletionConfetti") }
    }

    // Task Dates display options
    @Published var showStartDate: Bool {
        didSet { UserDefaults.standard.set(showStartDate, forKey: "showStartDate") }
    }
    @Published var showDueDate: Bool {
        didSet { UserDefaults.standard.set(showDueDate, forKey: "showDueDate") }
    }
    @Published var showEndDate: Bool {
        didSet { UserDefaults.standard.set(showEndDate, forKey: "showEndDate") }
    }
    @Published var showSyncStatus: Bool {
        didSet { UserDefaults.standard.set(showSyncStatus, forKey: "showSyncStatus") }
    }

    private init() {
        self.showDefaultColorBalls = UserDefaults.standard.object(forKey: "showDefaultColorBalls") as? Bool ?? true

        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        self.defaultSortOption = TaskSortOption(rawValue: sortOptionString) ?? .serverOrder

        let calendarSyncEnabled = UserDefaults.standard.object(forKey: "calendarSyncEnabled") as? Bool ?? false
        self.calendarSyncEnabled = calendarSyncEnabled
        self.autoSyncNewTasks = UserDefaults.standard.object(forKey: "autoSyncNewTasks") as? Bool ?? true
        self.syncTasksWithDatesOnly = UserDefaults.standard.object(forKey: "syncTasksWithDatesOnly") as? Bool ?? true
        CalendarSyncService.shared.setCalendarSyncEnabled(calendarSyncEnabled)
        // Initialize display options (all default to true for existing users)
        self.showAttachmentIcons = UserDefaults.standard.object(forKey: "showAttachmentIcons") as? Bool ?? true
        self.showCommentCounts = UserDefaults.standard.object(forKey: "showCommentCounts") as? Bool ?? true
        self.showPriorityIndicators = UserDefaults.standard.object(forKey: "showPriorityIndicators") as? Bool ?? true
        self.showTaskColors = UserDefaults.standard.object(forKey: "showTaskColors") as? Bool ?? true
        // Task Dates defaults
        self.showStartDate = UserDefaults.standard.object(forKey: "showStartDate") as? Bool ?? true
        self.showDueDate = UserDefaults.standard.object(forKey: "showDueDate") as? Bool ?? true
        self.showEndDate = UserDefaults.standard.object(forKey: "showEndDate") as? Bool ?? true
        self.showSyncStatus = UserDefaults.standard.object(forKey: "showSyncStatus") as? Bool ?? true
        // Celebration defaults (off)
        self.celebrateCompletionConfetti = UserDefaults.standard.object(forKey: "celebrateCompletionConfetti") as? Bool ?? false
    }

    // Static method to get default sort option without requiring main actor
    static func getDefaultSortOption() -> TaskSortOption {
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        return TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }
    
    // Add more settings here as needed
    // @Published var anotherSetting: Type { ... }
}