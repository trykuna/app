// Services/AppSettings.swift
import Foundation
import BackgroundTasks


@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private var isBootstrapping = true


    @Published var showDefaultColorBalls: Bool {
        didSet {
            UserDefaults.standard.set(showDefaultColorBalls, forKey: "showDefaultColorBalls")
            Analytics.trackSettingToggle("Settings.Task.DefaultColorBalls", enabled: showDefaultColorBalls)
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
            Analytics.trackSettingToggle("Settings.General.CalendarSyncEnabled", enabled: calendarSyncEnabled)
        }
    }

    @Published var autoSyncNewTasks: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncNewTasks, forKey: "autoSyncNewTasks")
            Analytics.trackSettingToggle("Settings.General.AutoSyncNewTasks", enabled: autoSyncNewTasks)
        }
    }

    @Published var syncTasksWithDatesOnly: Bool {
        didSet {
            UserDefaults.standard.set(syncTasksWithDatesOnly, forKey: "syncTasksWithDatesOnly")
            Analytics.trackSettingToggle("Settings.General.SyncTasksWithDatesOnly", enabled: syncTasksWithDatesOnly)
        }
    }

    // Display Options
    @Published var showAttachmentIcons: Bool {
        didSet {
            UserDefaults.standard.set(showAttachmentIcons, forKey: "showAttachmentIcons")
            Analytics.trackSettingToggle("Settings.Task.AttachmentIcons", enabled: showAttachmentIcons)
        }
    }

    @Published var showCommentCounts: Bool {
        didSet {
            UserDefaults.standard.set(showCommentCounts, forKey: "showCommentCounts")
            Analytics.trackSettingToggle("Settings.Task.CommentCounts", enabled: showCommentCounts)
        }
    }

    @Published var showPriorityIndicators: Bool {
        didSet {
            UserDefaults.standard.set(showPriorityIndicators, forKey: "showPriorityIndicators")
            Analytics.trackSettingToggle("Settings.Task.PriorityIndicators", enabled: showPriorityIndicators)
        }
    }

    @Published var showTaskColors: Bool {
        didSet {
            UserDefaults.standard.set(showTaskColors, forKey: "showTaskColors")
            Analytics.trackSettingToggle("Settings.Task.Colors", enabled: showTaskColors)
        }
    }

    // Celebration
    @Published var celebrateCompletionConfetti: Bool {
        didSet {
            UserDefaults.standard.set(celebrateCompletionConfetti, forKey: "celebrateCompletionConfetti")
            Analytics.trackSettingToggle("Settings.Task.CelebrateCompletion", enabled: celebrateCompletionConfetti)
        }
    }

    // Task Dates display options
    @Published var showStartDate: Bool {
        didSet {
            UserDefaults.standard.set(showStartDate, forKey: "showStartDate")
            Analytics.trackSettingToggle("Settings.Task.StartDate", enabled: showStartDate)
        }
    }
    @Published var showDueDate: Bool {
        didSet {
            UserDefaults.standard.set(showDueDate, forKey: "showDueDate")
            Analytics.trackSettingToggle("Settings.Task.DueDate", enabled: showDueDate)
        }
    }
    @Published var showEndDate: Bool {
        didSet {
            UserDefaults.standard.set(showEndDate, forKey: "showEndDate")
            Analytics.trackSettingToggle("Settings.Task.EndDate", enabled: showEndDate)
        }
    }
    @Published var showSyncStatus: Bool {
        didSet {
            UserDefaults.standard.set(showSyncStatus, forKey: "showSyncStatus")
            Analytics.trackSettingToggle("Settings.Task.SyncStatus", enabled: showSyncStatus)
        }
    }

    // MARK: - Background Sync & Notifications
    @Published var backgroundSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(backgroundSyncEnabled, forKey: "backgroundSyncEnabled")
            if backgroundSyncEnabled {
                BackgroundSyncService.shared.scheduleNext(after: backgroundSyncFrequency)
            } else {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundSyncService.shared.taskIdentifier)
            }
        }
    }

    @Published var backgroundSyncFrequency: BackgroundSyncService.Frequency {
        didSet {
            UserDefaults.standard.set(backgroundSyncFrequency.rawValue, forKey: "backgroundSyncFrequency")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundSyncService.shared.taskIdentifier)
            if backgroundSyncEnabled { BackgroundSyncService.shared.scheduleNext(after: backgroundSyncFrequency) }
        }
    }

    @Published var notifyNewTasks: Bool { didSet { UserDefaults.standard.set(notifyNewTasks, forKey: "notifyNewTasks") } }
    @Published var notifyUpdatedTasks: Bool { didSet { UserDefaults.standard.set(notifyUpdatedTasks, forKey: "notifyUpdatedTasks") } }
    @Published var notifyAssignedToMe: Bool { didSet { UserDefaults.standard.set(notifyAssignedToMe, forKey: "notifyAssignedToMe") } }
    @Published var notifyLabelsUpdated: Bool { didSet { UserDefaults.standard.set(notifyLabelsUpdated, forKey: "notifyLabelsUpdated") } }
    @Published var watchedLabelIDs: [Int] { didSet { UserDefaults.standard.set(watchedLabelIDs, forKey: "watchedLabelIDs") } }
    @Published var notifyWithSummary: Bool { didSet { UserDefaults.standard.set(notifyWithSummary, forKey: "notifyWithSummary") } }

    // MARK: - Analytics Preference
    @Published var analyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled")
            if !isBootstrapping {
                Analytics.trackSettingToggle("Settings.General.AnalyticsEnabled", enabled: analyticsEnabled)
            }
        }
    }
    // Stores raw consent decision so we know whether to re-prompt
    // Values: "granted", "denied"; nil means not decided yet
    @Published var analyticsConsentDecision: String? {
        didSet {
            UserDefaults.standard.set(analyticsConsentDecision, forKey: "analyticsConsentDecision")
            if !isBootstrapping, let decision = analyticsConsentDecision {
                Analytics.track("Settings.General.AnalyticsConsentChanged", parameters: ["decision": decision])
            }
        }
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

        // Analytics defaults: disabled until user decides
        self.analyticsEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? false
        self.analyticsConsentDecision = UserDefaults.standard.string(forKey: "analyticsConsentDecision")

        // Background Sync & Notifications defaults
        self.backgroundSyncEnabled = UserDefaults.standard.object(forKey: "backgroundSyncEnabled") as? Bool ?? false
        if let raw = UserDefaults.standard.string(forKey: "backgroundSyncFrequency"), let f = BackgroundSyncService.Frequency(rawValue: raw) {
            self.backgroundSyncFrequency = f
        } else {
            self.backgroundSyncFrequency = .h6
        }
        self.notifyNewTasks = UserDefaults.standard.object(forKey: "notifyNewTasks") as? Bool ?? false
        self.notifyUpdatedTasks = UserDefaults.standard.object(forKey: "notifyUpdatedTasks") as? Bool ?? false
        self.notifyAssignedToMe = UserDefaults.standard.object(forKey: "notifyAssignedToMe") as? Bool ?? true
        self.notifyLabelsUpdated = UserDefaults.standard.object(forKey: "notifyLabelsUpdated") as? Bool ?? false
        self.watchedLabelIDs = (UserDefaults.standard.array(forKey: "watchedLabelIDs") as? [Int]) ?? []
        self.notifyWithSummary = UserDefaults.standard.object(forKey: "notifyWithSummary") as? Bool ?? true

        self.isBootstrapping = false
    }

    // Static method to get default sort option without requiring main actor
    static func getDefaultSortOption() -> TaskSortOption {
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        return TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }

    // Reset all user settings back to defaults (called on sign out)
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "showDefaultColorBalls",
            "defaultSortOption",
            "calendarSyncEnabled",
            "autoSyncNewTasks",
            "syncTasksWithDatesOnly",
            "showAttachmentIcons",
            "showCommentCounts",
            "showPriorityIndicators",
            "showTaskColors",
            "celebrateCompletionConfetti",
            "showStartDate",
            "showDueDate",
            "showEndDate",
            "showSyncStatus",
            "analyticsEnabled",
            "analyticsConsentDecision"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }

        // Reinitialize published properties to constructor defaults
        self.showDefaultColorBalls = true
        self.defaultSortOption = .serverOrder
        self.calendarSyncEnabled = false
        self.autoSyncNewTasks = true
        self.syncTasksWithDatesOnly = true
        self.showAttachmentIcons = true
        self.showCommentCounts = true
        self.showPriorityIndicators = true
        self.showTaskColors = true
        self.celebrateCompletionConfetti = false
        self.showStartDate = true
        self.showDueDate = true
        self.showEndDate = true
        self.showSyncStatus = true
        self.analyticsEnabled = false
        self.analyticsConsentDecision = nil

        CalendarSyncService.shared.setCalendarSyncEnabled(false)
    }
}
