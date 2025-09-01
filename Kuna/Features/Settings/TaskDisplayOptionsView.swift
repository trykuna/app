//
//  TaskVDisplayView.swift
//  Kuna
//
//  Created by Richard Annand on 17/08/2025.
//

import SwiftUI

struct TaskDisplayOptionsView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            List {
                // Live Preview
                Section {
                    DisplayPreviewRow(settings: settings)
                // } header: { Text("Preview") } footer: {
                } header: { Text(String(localized: "common.preview", comment: "Preview header")) } footer: {
                    // Text("Live preview of task list appearance based on your settings.")
                    Text(String(localized: "settings.display.preview.title",
                                comment: "Title for live preview of task list appearance based on your settings"))
                }

                // Example: Task Colors toggle
                Section {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Task Colors").font(.body)
                            Text(String(localized: "settings.display.colours.title",
                                        comment: "Title for task colors")).font(.body)
                            // Text("Display color indicators for all tasks")
                            Text(String(localized: "settings.display.colours.description",
                                        comment: "Display color indicators for all tasks"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Toggle("", isOn: $settings.showTaskColors).labelsHidden()
                    }
                    if settings.showTaskColors {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .frame(width: 20, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                // Text("Default Color Balls").font(.body)
                                Text(String(localized: "settings.display.colours.defaultBalls.title",
                                            comment: "Title for default color balls")).font(.body)
                                // Text("Use the default blue color for task color indicators")
                                Text(String(localized: "settings.display.colours.defaultBalls.description",
                                            comment: "Use the default blue color for task color indicators"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.showDefaultColorBalls).labelsHidden()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Attachment Icons").font(.body)
                            Text(String(localized: "settings.display.attachments.title",
                                        comment: "Title for attachment icons")).font(.body)
                            // Text("Show paperclip icons for tasks with attachments")
                            Text(String(localized: "settings.display.attachments.description",
                                        comment: "Show paperclip icons for tasks with attachments"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Toggle("", isOn: $settings.showAttachmentIcons).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Comment Counts").font(.body)
                            Text(String(localized: "settings.display.comments.title",
                                        comment: "Title for comment counts")).font(.body)
                            // Text("Show comment count badges on tasks")
                            Text(String(localized: "settings.display.comments.description",
                                        comment: "Show comment count badges on tasks"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Toggle("", isOn: $settings.showCommentCounts).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Priority Indicators").font(.body)
                            Text(String(localized: "settings.display.priority.title",
                                        comment: "Title for priority indicators")).font(.body)
                            // Text("Show priority indicators on tasks")
                            Text(String(localized: "settings.display.priority.description",
                                        comment: "Show priority indicators on tasks"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Toggle("", isOn: $settings.showPriorityIndicators).labelsHidden()
                    }
                } header: { 
                    // Text("Display Options")
                    Text(String(localized: "settings.display.title", comment: "Display options settings header"))
                }
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Start Date").font(.body)
                            Text(String(localized: "tasks.startDate", comment: "Title for start date")).font(.body)
                            // Text("Show a task's start date")
                            Text(String(localized: "settings.display.dates.startDate.description",
                                        comment: "Show a task's start date"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.showStartDate).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Due Date").font(.body)
                            Text(String(localized: "settings.display.dates.dueDate.title",
                                        comment: "Title for due date")).font(.body)
                            // Text("Show a task's due date")
                            Text(String(localized: "settings.display.dates.dueDate.description",
                                        comment: "Show a task's due date"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.showDueDate).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            // Text("End Date").font(.body)
                            Text(String(localized: "settings.display.dates.endDate.title",
                                        comment: "Title for end date")).font(.body)
                            // Text("Show a task's end date")
                            Text(String(localized: "settings.display.dates.endDate.description",
                                        comment: "Show a task's end date"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.showEndDate).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Sync Status").font(.body)
                            Text(String(localized: "settings.display.syncStatus.title",
                                        comment: "Title for sync status")).font(.body)
                            // Text("Show whether a task is synced to Calendar")
                            Text(String(localized: "settings.display.syncStatus.description",
                                        comment: "Show whether a task is synced to calendar"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.showSyncStatus).labelsHidden()
                    }

                // } header: { Text("Task Dates") }
                } header: { Text(String(localized: "settings.display.dates.header", comment: "Task dates header")) }

                // Celebration
                Section {
                    HStack {
                        Image(systemName: "party.popper.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            // Text("Celebrate Completion").font(.body)
                            Text(String(localized: "settings.display.celebration.title",
                                        comment: "Title for celebrate completion")).font(.body)
                            // Text("Show confetti when marking a task complete")
                            Text(String(localized: "settings.display.celebration.description",
                                        comment: "Show confetti when marking a task complete"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.celebrateCompletionConfetti).labelsHidden()
                    }
                // } header: { Text("Celebration") }
                } header: { Text(String(localized: "settings.display.celebration.header", comment: "Celebration header")) }
            }
            // .navigationTitle("Display Options")
            .navigationTitle(String(localized: "settings.display.title", comment: "Display options navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: settings.showTaskColors)
        }
    }
}

// MARK: - Live Preview Row (mirrors TaskListView row)
private struct DisplayPreviewRow: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        HStack(spacing: 12) {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                if settings.showTaskColors && settings.showDefaultColorBalls {
                    Circle()
                        .fill(Color(hex: "007AFF") ?? .blue)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // Text("Sample task title")
                        Text(String(localized: "settings.display.preview.sampleTitle", comment: "Title for sample task"))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if settings.showPriorityIndicators {
                            Image(systemName: TaskPriority.high.systemImage)
                                .foregroundColor(TaskPriority.high.color)
                                .font(.body)
                                .frame(width: 16, height: 16)
                        }
                        Spacer()
                    }

                    // Labels example (kept simple)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach([Label(id: 1, title: "Network", hexColor: "34C759", description: nil),
                                     Label(id: 2, title: "Ops", hexColor: "FF9500", description: nil)], id: \.id) { label in
                                Text(label.title)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(label.color.opacity(0.2))
                                    .foregroundColor(label.color)
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // Dates row (respect toggles)
                    HStack(spacing: 4) {
                        if settings.showStartDate {
                            Chip(icon: "play.circle.fill", color: .green, text: "23 Aug 2025\n21:46")
                        }
                        if settings.showDueDate {
                            Chip(icon: "clock.fill", color: .orange, text: "23 Aug 2025\n21:46")
                        }
                        if settings.showEndDate {
                            Chip(icon: "checkmark.circle.fill", color: .blue, text: "24 Aug 2025\n01:29")
                        }
                    }

                    // Extra indicators
                    HStack(spacing: 4) {
                        if settings.showAttachmentIcons {
                            Image(systemName: "paperclip").font(.caption).foregroundColor(.secondary)
                        }
                        if settings.showCommentCounts {
                            CommentBadge(commentCount: 3)
                        }
                        if settings.showSyncStatus && AppSettings.shared.calendarSyncEnabled {
                            Chip(icon: "calendar.badge.checkmark", color: .green, text: "Synced")
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

private struct Chip: View {
        let icon: String
        let color: Color
        let text: String
        var body: some View {
            HStack(spacing: 2) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(text).font(.caption2).foregroundColor(color)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .cornerRadius(3)
        }
    }

#Preview {
    TaskDisplayOptionsView()
        .environmentObject(AppState())
}
