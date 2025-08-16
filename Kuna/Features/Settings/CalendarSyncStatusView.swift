// Features/Settings/CalendarSyncStatusView.swift
import SwiftUI

struct CalendarSyncStatusView: View {
    @StateObject private var calendarSync = CalendarSyncService.shared
    @StateObject private var syncManager = CalendarSyncManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Sync Status Section
                Section("Sync Status") {
                    HStack {
                        Image(systemName: syncStatusIcon)
                            .foregroundColor(syncStatusColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncStatusText)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let lastSync = syncManager.lastSyncDate {
                                Text("Last synced: \(lastSync, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if syncManager.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if syncManager.canPerformSync() && !syncManager.isSyncing {
                        Button("Sync Now") {
                            performManualSync()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar Information
                if let calendar = calendarSync.selectedCalendar {
                    Section("Calendar Details") {
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if let source = calendar.source {
                                    Text(source.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(calendar.allowsContentModifications ? "Writable" : "Read-only")
                                .font(.caption)
                                .foregroundColor(calendar.allowsContentModifications ? .green : .orange)
                        }
                    }
                }
                
                // Sync Conflicts
                if !syncManager.syncConflicts.isEmpty {
                    Section("Sync Conflicts") {
                        ForEach(syncManager.syncConflicts) { conflict in
                            ConflictRow(conflict: conflict) {
                                // Handle conflict resolution
                                Task {
                                    await syncManager.resolveConflict(
                                        conflict,
                                        resolution: .preferTask,
                                        api: appState.api!
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Sync Errors
                if !calendarSync.syncErrors.isEmpty {
                    Section("Recent Errors") {
                        ForEach(calendarSync.syncErrors, id: \.self) { error in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(.red)
                                
                                Text(Date(), style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Button("Clear Errors") {
                            calendarSync.clearErrors()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Sync Statistics
                Section("Statistics") {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green)
                        Text("Synced Events")
                        Spacer()
                        Text("\(syncedEventsCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Conflicts")
                        Spacer()
                        Text("\(syncManager.syncConflicts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                        Text("Errors")
                        Spacer()
                        Text("\(calendarSync.syncErrors.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Calendar Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var syncStatusIcon: String {
        if syncManager.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if !syncManager.canPerformSync() {
            return "exclamationmark.triangle"
        } else if !calendarSync.syncErrors.isEmpty {
            return "xmark.circle"
        } else if !syncManager.syncConflicts.isEmpty {
            return "exclamationmark.triangle"
        } else {
            return "checkmark.circle"
        }
    }
    
    private var syncStatusColor: Color {
        if syncManager.isSyncing {
            return .blue
        } else if !syncManager.canPerformSync() {
            return .orange
        } else if !calendarSync.syncErrors.isEmpty {
            return .red
        } else if !syncManager.syncConflicts.isEmpty {
            return .orange
        } else {
            return .green
        }
    }
    
    private var syncStatusText: String {
        if syncManager.isSyncing {
            return "Syncing..."
        } else if !syncManager.canPerformSync() {
            return "Sync Not Available"
        } else if !calendarSync.syncErrors.isEmpty {
            return "Sync Errors"
        } else if !syncManager.syncConflicts.isEmpty {
            return "Sync Conflicts"
        } else {
            return "Sync Ready"
        }
    }
    
    private var syncedEventsCount: Int {
        guard let calendar = calendarSync.selectedCalendar else { return 0 }
        
        let predicate = calendarSync.eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            end: Date().addingTimeInterval(30 * 24 * 60 * 60),
            calendars: [calendar]
        )
        
        let events = calendarSync.eventStore.events(matching: predicate)
        return events.filter { event in
            event.url?.absoluteString.hasPrefix("kuna://task/") == true
        }.count
    }
    
    // MARK: - Actions
    
    private func performManualSync() {
        guard let api = appState.api else { return }
        
        Task {
            // For now, sync all projects. In a real implementation,
            // you might want to sync only the current project
            await syncManager.performFullSync(api: api, projectId: 1)
        }
    }
}

struct ConflictRow: View {
    let conflict: SyncConflict
    let onResolve: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: conflict.conflictType.systemImage)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.taskTitle)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Conflict: \(conflict.conflictType.rawValue)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            
            HStack {
                Button("Use Task") {
                    onResolve()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Use Calendar") {
                    onResolve()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Normal State") {
    CalendarSyncStatusView()
        .environmentObject(AppState())
}

#Preview("With Conflicts") {
    let view = CalendarSyncStatusView()
    let syncManager = CalendarSyncManager.shared

    // Add some mock conflicts for preview
    syncManager.syncConflicts = [
        SyncConflict(
            taskId: 1,
            taskTitle: "Sample Task with Conflict",
            taskLastModified: Date().addingTimeInterval(-3600),
            eventLastModified: Date(),
            conflictType: .title
        ),
        SyncConflict(
            taskId: 2,
            taskTitle: "Another Conflicted Task",
            taskLastModified: Date(),
            eventLastModified: Date().addingTimeInterval(-1800),
            conflictType: .startDate
        )
    ]

    return view.environmentObject(AppState())
}

#Preview("With Errors") {
    let view = CalendarSyncStatusView()
    let calendarSync = CalendarSyncService.shared

    // Add some mock errors for preview
    calendarSync.syncErrors = [
        "Failed to sync task 'Important Meeting': Calendar access denied",
        "Failed to update event: Network connection lost",
        "Task 'Project Deadline' could not be found in calendar"
    ]

    return view.environmentObject(AppState())
}
#endif
