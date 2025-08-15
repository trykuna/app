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
    
    private init() {
        self.showDefaultColorBalls = UserDefaults.standard.object(forKey: "showDefaultColorBalls") as? Bool ?? true
        
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        self.defaultSortOption = TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }
    
    // Static method to get default sort option without requiring main actor
    static func getDefaultSortOption() -> TaskSortOption {
        let sortOptionString = UserDefaults.standard.string(forKey: "defaultSortOption") ?? TaskSortOption.serverOrder.rawValue
        return TaskSortOption(rawValue: sortOptionString) ?? .serverOrder
    }
    
    // Add more settings here as needed
    // @Published var anotherSetting: Type { ... }
}