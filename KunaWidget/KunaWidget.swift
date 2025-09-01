//
//  KunaWidget.swift
//  KunaWidget
//
//  Created by Richard Annand on 20/08/2025.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Cache Types
private struct SharedTaskSnapshot: Codable {
    struct Item: Codable {
        let id: Int
        let title: String
        let dueDate: Date
        let isOverdue: Bool
        let priority: String        // "low" | "medium" | "high" | "urgent" | "doNow" | "unset"
        let projectId: Int?
    }
    let generatedAt: Date
    let items: [Item]
}

// MARK: - Shared Store
private class SharedStore {
    private static let appGroupID = "group.tech.systemsmystery.kuna"
    private static let snapshotKey = "shared_tasks_snapshot_v1"
    
    static func readSnapshot() -> SharedTaskSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else {
            print("Widget: No snapshot data found")
            return nil
        }
        
        do {
            let snapshot = try JSONDecoder().decode(SharedTaskSnapshot.self, from: data)
            print("Widget: Read snapshot with \(snapshot.items.count) tasks from \(snapshot.generatedAt)")
            return snapshot
        } catch {
            print("Widget: Failed to decode snapshot: \(error)")
            return nil
        }
    }
}

// MARK: - Small Widget Provider (with priority filter)
struct SmallWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [
            WidgetTask(id: 1, title: "Sample Task", dueDate: Date(), isOverdue: false, priority: .medium),
            WidgetTask(id: 2, title: "Another Task", dueDate: Date(), isOverdue: true, priority: .high)
        ], projectName: "All Projects", configuredPriority: nil, projectId: nil)
    }

    func snapshot(for configuration: ProjectSelectionConfiguration, in context: Context) async -> SimpleEntry {
        return SimpleEntry(date: Date(), tasks: [
            WidgetTask(id: 1, title: "Review Project", dueDate: Date(), isOverdue: false, priority: .high),
            WidgetTask(id: 2, title: "Team Meeting", dueDate: Date(), isOverdue: true, priority: .medium),
            WidgetTask(id: 3, title: "Update Documentation", dueDate: Date(), isOverdue: false, priority: .low)
        ], 
        projectName: configuration.project?.displayName ?? "All Projects",
        configuredPriority: configuration.priorityFilter?.priority,
        projectId: configuration.project?.projectId)
    }

    func timeline(for configuration: ProjectSelectionConfiguration, in context: Context) async -> Timeline<SimpleEntry> {
        let tasks: [WidgetTask]
        
        // Try to read from cached snapshot first
        if let snapshot = SharedStore.readSnapshot() {
            print("Widget: Using cached snapshot with \(snapshot.items.count) tasks")
            tasks = filterTasks(from: snapshot.items, configuration: configuration)
        } else {
            print("Widget: No cache found, falling back to API")
            // Fallback to API if cache is empty
            tasks = await WidgetDataService.shared.getTasks(
                projectId: configuration.project?.projectId,
                priorityFilter: configuration.priorityFilter?.priority,
                showTodayOnly: false,
                showOverdue: true
            )
        }
        
        let projectName = configuration.project?.displayName ?? "All Projects"
        let entry = SimpleEntry(date: Date(), tasks: tasks, projectName: projectName, configuredPriority: configuration.priorityFilter?.priority, projectId: configuration.project?.projectId)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))) // Refresh hourly
        return timeline
    }
    
    private func filterTasks(from items: [SharedTaskSnapshot.Item], configuration: ProjectSelectionConfiguration) -> [WidgetTask] {
        var filteredItems = items
        
        // Filter by project
        if let projectId = configuration.project?.projectId {
            filteredItems = filteredItems.filter { $0.projectId == projectId }
        }
        
        // Filter by priority
        if let priorityFilter = configuration.priorityFilter?.priority {
            filteredItems = filteredItems.filter { 
                mapPriorityString($0.priority) == priorityFilter 
            }
        }
        
        // Convert to WidgetTask
        return filteredItems.map { item in
            WidgetTask(
                id: item.id,
                title: item.title,
                dueDate: item.dueDate,
                isOverdue: item.isOverdue,
                priority: mapPriorityString(item.priority)
            )
        }
    }
    
    private func mapPriorityString(_ priorityString: String) -> WidgetTaskPriority {
        switch priorityString.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        case "urgent": return .urgent
        case "donow": return .doNow
        default: return .unset
        }
    }
}

// MARK: - Medium Widget Provider (project only)
struct MediumWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [
            WidgetTask(id: 1, title: "Sample Task", dueDate: Date(), isOverdue: false, priority: .medium),
            WidgetTask(id: 2, title: "Another Task", dueDate: Date(), isOverdue: true, priority: .high),
            WidgetTask(id: 3, title: "Third Task", dueDate: Date(), isOverdue: false, priority: .low)
        ], projectName: "All Projects", configuredPriority: nil, projectId: nil)
    }

    func snapshot(for configuration: ProjectOnlyConfiguration, in context: Context) async -> SimpleEntry {
        return SimpleEntry(date: Date(), tasks: [
            WidgetTask(id: 1, title: "Review Project", dueDate: Date(), isOverdue: false, priority: .high),
            WidgetTask(id: 2, title: "Team Meeting", dueDate: Date(), isOverdue: true, priority: .medium),
            WidgetTask(id: 3, title: "Update Documentation", dueDate: Date(), isOverdue: false, priority: .low),
            WidgetTask(id: 4, title: "Bug Fix", dueDate: Date(), isOverdue: false, priority: .urgent)
        ], projectName: configuration.project?.displayName ?? "All Projects", configuredPriority: nil, projectId: configuration.project?.projectId)
    }

    func timeline(for configuration: ProjectOnlyConfiguration, in context: Context) async -> Timeline<SimpleEntry> {
        let tasks: [WidgetTask]
        
        // Try to read from cached snapshot first
        if let snapshot = SharedStore.readSnapshot() {
            print("Widget: Using cached snapshot with \(snapshot.items.count) tasks")
            tasks = filterTasksByProject(from: snapshot.items, configuration: configuration)
        } else {
            print("Widget: No cache found, falling back to API")
            // Fallback to API if cache is empty - get ALL priorities for the project
            tasks = await WidgetDataService.shared.getTasks(
                projectId: configuration.project?.projectId,
                priorityFilter: nil, // No priority filter for medium widget
                showTodayOnly: false,
                showOverdue: true
            )
        }
        
        let projectName = configuration.project?.displayName ?? "All Projects"
        let entry = SimpleEntry(date: Date(), tasks: tasks, projectName: projectName, configuredPriority: nil, projectId: configuration.project?.projectId)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))) // Refresh hourly
        return timeline
    }
    
    private func filterTasksByProject(from items: [SharedTaskSnapshot.Item], configuration: ProjectOnlyConfiguration) -> [WidgetTask] {
        var filteredItems = items
        
        // Filter by project only (no priority filter)
        if let projectId = configuration.project?.projectId {
            filteredItems = filteredItems.filter { $0.projectId == projectId }
        }
        
        // Convert to WidgetTask
        return filteredItems.map { item in
            WidgetTask(
                id: item.id,
                title: item.title,
                dueDate: item.dueDate,
                isOverdue: item.isOverdue,
                priority: mapPriorityString(item.priority)
            )
        }
    }
    
    private func mapPriorityString(_ priorityString: String) -> WidgetTaskPriority {
        switch priorityString.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        case "urgent": return .urgent
        case "donow": return .doNow
        default: return .unset
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let projectName: String
    let configuredPriority: WidgetTaskPriority?
    let projectId: Int?
}

struct WidgetTask {
    let id: Int
    let title: String
    let dueDate: Date
    let isOverdue: Bool
    let priority: WidgetTaskPriority
}

struct KunaWidgetEntryView : View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: SimpleEntry
    
    private var tasks: [WidgetTask] { entry.tasks }
    
    // Get the configured priority from the widget configuration
    private var configuredPriority: WidgetTaskPriority? {
        return entry.configuredPriority
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: Project name
            Text(entry.projectName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 20)
            
            Spacer()
            
            // Middle: Large task count and label
            VStack(spacing: 4) {
                Text("\(tasks.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(tasks.count == 1 ? "task" : "tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.lowercase)
            }
            
            Spacer()
            
            // Bottom: Priority badge (if filtering by specific priority)
            if let priority = configuredPriority, priority != .unset {
                priorityBadge(for: priority)
                    .padding(.bottom, 20)
            } else {
                // Add bottom padding when no badge
                Spacer()
                    .frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func priorityBadge(for priority: WidgetTaskPriority) -> some View {
        HStack(spacing: 6) {
            Image(systemName: priorityIcon(for: priority))
                .font(.system(size: 12, weight: .semibold))
            
            Text(priorityLabel(for: priority))
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(priorityColor(for: priority))
        )
    }
    
    private func priorityIcon(for priority: WidgetTaskPriority) -> String {
        switch priority {
        case .unset: return "minus"
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        case .doNow: return "exclamationmark.2"
        }
    }
    
    private func priorityColor(for priority: WidgetTaskPriority) -> Color {
        switch priority {
        case .unset: return .gray
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        case .doNow: return .purple
        }
    }
    
    private func priorityLabel(for priority: WidgetTaskPriority) -> String {
        switch priority {
        case .unset: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .doNow: return "Critical"
        }
    }
}

struct MediumWidgetView: View {
    let entry: SimpleEntry
    
    private var tasks: [WidgetTask] { entry.tasks }
    
    // For medium widget, we need ALL tasks from the project, not filtered by priority
    // So we'll need to get all project tasks and calculate counts from them
    private var priorityCounts: [WidgetTaskPriority: Int] {
        // Get all tasks from the project (ignoring priority filter)
        let allProjectTasks = getAllProjectTasks()
        
        var counts: [WidgetTaskPriority: Int] = [:]
        for priority in WidgetTaskPriority.allCases {
            counts[priority] = allProjectTasks.filter { $0.priority == priority }.count
        }
        return counts
    }
    
    private func getAllProjectTasks() -> [WidgetTask] {
        // Read from cache and filter by project only (no priority filter)
        guard let snapshot = SharedStore.readSnapshot() else {
            return tasks // Fallback to current tasks if no cache
        }
        
        var allItems = snapshot.items
        
        // Filter by project only (get all priorities for this project)
        if let projectId = getProjectId() {
            allItems = allItems.filter { $0.projectId == projectId }
        }
        
        // Convert to WidgetTask
        return allItems.map { item in
            WidgetTask(
                id: item.id,
                title: item.title,
                dueDate: item.dueDate,
                isOverdue: item.isOverdue,
                priority: mapPriorityString(item.priority)
            )
        }
    }
    
    private func getProjectId() -> Int? {
        return entry.projectId
    }
    
    private func mapPriorityString(_ priorityString: String) -> WidgetTaskPriority {
        switch priorityString.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        case "urgent": return .urgent
        case "donow": return .doNow
        default: return .unset
        }
    }
    
    private var totalTasks: Int {
        tasks.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with project name
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(entry.projectName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Total count
            HStack {
                Text("\(totalTasks) tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Priority breakdown - horizontal layout
            HStack(spacing: 0) {
                ForEach([WidgetTaskPriority.doNow, .urgent, .high, .medium, .low, .unset], id: \.self) { priority in
                    let count = priorityCounts[priority] ?? 0
                    priorityColumn(priority: priority, count: count)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func priorityColumn(priority: WidgetTaskPriority, count: Int) -> some View {
        VStack(spacing: 4) {
            // Priority icon
            Image(systemName: priorityIcon(for: priority))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(priorityColor(for: priority))
                .frame(height: 20)
            
            // Count
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Priority label (abbreviated)
            Text(abbreviatedLabel(for: priority))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .opacity(count > 0 ? 1.0 : 0.4) // Dim columns with zero count
    }
    
    private func abbreviatedLabel(for priority: WidgetTaskPriority) -> String {
        switch priority {
        case .unset: return "None"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .doNow: return "Now!"
        }
    }
    
    private func priorityIcon(for priority: WidgetTaskPriority) -> String {
        switch priority {
        case .unset: return "minus"
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        case .doNow: return "exclamationmark.2"
        }
    }
    
    private func priorityColor(for priority: WidgetTaskPriority) -> Color {
        switch priority {
        case .unset: return .gray
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        case .doNow: return .purple
        }
    }
    
    private func priorityLabel(for priority: WidgetTaskPriority) -> String {
        switch priority {
        case .unset: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .doNow: return "Do Now!"
        }
    }
}

struct LargeWidgetView: View {
    let entry: SimpleEntry
    
    private var tasks: [WidgetTask] { entry.tasks }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(.blue)
                Text(entry.projectName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(tasks.count) total")
                        .font(.caption)
                    Text("\(tasks.filter { $0.isOverdue }.count) overdue")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(task.isOverdue ? Color.red : Color.gray, lineWidth: 2)
                                .frame(width: 16, height: 16)
                            
                            if !task.priority.systemImage.isEmpty {
                                Image(systemName: task.priority.systemImage)
                                    .font(.caption)
                                    .foregroundColor(task.priority.color)
                                    .frame(width: 16)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.body)
                                    .foregroundColor(task.isOverdue ? .red : .primary)
                                    .lineLimit(2)
                                
                                Text(formatDueDate(task.dueDate, isOverdue: task.isOverdue))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.all, 16)
    }
}

private func formatDueDate(_ date: Date, isOverdue: Bool) -> String {
    if isOverdue {
        return "Overdue"
    }
    
    let formatter = DateFormatter()
    if Calendar.current.isDateInToday(date) {
        formatter.timeStyle = .short
        return "Today \(formatter.string(from: date))"
    } else {
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct KunaWidget: Widget {
    let kind: String = "KunaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ProjectSelectionConfiguration.self, provider: SmallWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                KunaWidgetEntryView(entry: entry)
                    .containerBackground(Color.clear, for: .widget)
            } else {
                KunaWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.clear)
            }
        }
        .configurationDisplayName("Task Count")
        .description("View task count for selected project and priority.")
        .supportedFamilies([.systemSmall])
    }
}

struct KunaPriorityWidget: Widget {
    let kind: String = "KunaPriorityWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ProjectOnlyConfiguration.self, provider: MediumWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                KunaWidgetEntryView(entry: entry)
                    .containerBackground(Color.clear, for: .widget)
            } else {
                KunaWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.clear)
            }
        }
        .configurationDisplayName("Priority Breakdown")
        .description("View priority breakdown for selected project.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemSmall) {
    KunaWidget()
} timeline: {
    SimpleEntry(date: .now, tasks: [
        WidgetTask(id: 1, title: "Review Project Plan", dueDate: Date(), isOverdue: false, priority: .high),
        WidgetTask(id: 2, title: "Team Meeting Setup", dueDate: Date(), isOverdue: true, priority: .high),
        WidgetTask(id: 3, title: "Update Documentation", dueDate: Date(), isOverdue: false, priority: .high)
    ], projectName: "Sample Project", configuredPriority: .high, projectId: 1)
}
