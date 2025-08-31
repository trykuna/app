// Features/Tasks/TaskDetailView_Previews.swift
import SwiftUI

#if DEBUG
struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let demoTask = VikunjaTask(
            id: 123,
            title: "Design API for relations",
            description: "We should support subtask/parent, duplicate, related, etc.",
            done: false,
            dueDate: Date().addingTimeInterval(86400 * 3),
            startDate: nil,
            endDate: nil,
            labels: [Label(id: 1, title: "Backend", hexColor: "#3498db", description: nil)],
            reminders: [],
            priority: .medium,
            percentDone: 0.35,
            hexColor: "#3498db",
            repeatAfter: nil,
            repeatMode: .afterAmount,
            assignees: [],
            createdBy: VikunjaUser(id: 1, username: "demo", name: "Demo User"),
            projectId: 1,
            isFavorite: false,
            attachments: [],
            commentCount: 2,
            updatedAt: Date()
        )

        // Minimal API stub just to satisfy the view; does not perform real network calls in preview.
        let api = VikunjaAPI(
            config: VikunjaConfig(baseURL: URL(string: "https://example.com/api/v1")!), // swiftlint:disable:this force_unwrapping
            tokenProvider: { nil }
        )

        // Provide AppState environment so the view compiles
        let appState = AppState()
        appState.api = api

        return TaskDetailView(task: demoTask, api: api, onUpdate: nil)
            .environmentObject(appState)
            .previewDisplayName("Task Detail (Demo)")
    }
}
#endif
