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

    private init() {
        self.showDefaultColorBalls = UserDefaults.standard.object(forKey: "showDefaultColorBalls") as? Bool ?? true

        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        self.defaultSortOption = TaskSortOption(rawValue: sortOptionString) ?? .serverOrder

        self.calendarSyncEnabled = UserDefaults.standard.object(forKey: "calendarSyncEnabled") as? Bool ?? false
        self.autoSyncNewTasks = UserDefaults.standard.object(forKey: "autoSyncNewTasks") as? Bool ?? true
        self.syncTasksWithDatesOnly = UserDefaults.standard.object(forKey: "syncTasksWithDatesOnly") as? Bool ?? true
    }
    
    // Static method to get default sort option without requiring main actor
    static func getDefaultSortOption() -> TaskSortOption {
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        return TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }
    
    // Add more settings here as needed
    // @Published var anotherSetting: Type { ... }
}