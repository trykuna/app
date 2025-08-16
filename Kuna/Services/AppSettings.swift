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
    
    private init() {
        self.showDefaultColorBalls = UserDefaults.standard.object(forKey: "showDefaultColorBalls") as? Bool ?? true

        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        self.defaultSortOption = TaskSortOption(rawValue: sortOptionString) ?? .serverOrder

        // Initialize display options (all default to true for existing users)
        self.showAttachmentIcons = UserDefaults.standard.object(forKey: "showAttachmentIcons") as? Bool ?? true
        self.showCommentCounts = UserDefaults.standard.object(forKey: "showCommentCounts") as? Bool ?? true
        self.showPriorityIndicators = UserDefaults.standard.object(forKey: "showPriorityIndicators") as? Bool ?? true
        self.showTaskColors = UserDefaults.standard.object(forKey: "showTaskColors") as? Bool ?? true
    }
    
    // Static method to get default sort option without requiring main actor
    static func getDefaultSortOption() -> TaskSortOption {
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        return TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }
    
    // Add more settings here as needed
    // @Published var anotherSetting: Type { ... }
}