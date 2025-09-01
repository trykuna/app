import SwiftUI
import Foundation
import os

// Keep save logic out of the main view file for clarity
extension TaskDetailView {

    /// Persists edits to the API and updates local state.
    func saveChanges() async {
        isUpdating = true
        defer { isUpdating = false }

        // Move buffered edits into the task
        task.description = editedDescription.isEmpty ? nil : editedDescription

        Log.app.debug("🔍 Processing edit buffers:")
        Log.app.debug("  - editStartDate: \(editStartDate?.description ?? "nil") (hasTime: \(startHasTime))")
        Log.app.debug("  - editDueDate: \(editDueDate?.description ?? "nil") (hasTime: \(dueHasTime))")
        Log.app.debug("  - editEndDate: \(editEndDate?.description ?? "nil") (hasTime: \(endHasTime))")
        Log.app.debug("Using workaround repeat - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
        Log.app.debug("Using workaround repeat - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")

        let taskToSave = buildTaskToSave()

        Log.app.debug("Created new task instance with dates")
        Log.app.debug("taskToSave dates - start: \(taskToSave.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("taskToSave dates - due: \(taskToSave.dueDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("taskToSave dates - end: \(taskToSave.endDate?.description ?? "nil", privacy: .public)")

        do {
            Log.app.debug("Saving task \(taskToSave.id, privacy: .public) with updated dates")
            Log.app.debug("Saving task with repeat: after=\(taskToSave.repeatAfter?.description ?? "nil", privacy: .public)")
            Log.app.debug("Saving task with repeat mode: \(taskToSave.repeatMode.displayName, privacy: .public)")

            // Inspect payload
            if let encoded = try? JSONEncoder.vikunja.encode(taskToSave),
               let jsonString = String(data: encoded, encoding: .utf8) {
                Log.app.debug("JSON payload being sent to API")
                Log.app.debug("JSON content: \(jsonString, privacy: .private)")
            }

            let updatedTask = try await api.updateTask(taskToSave)
            try await applyUpdatedTask(updatedTask)

        } catch {
            Log.app.error("Failed to save task: \(String(describing: error), privacy: .public)")
            updateError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    /// Build the object we send to the API using the current edit buffers.
    private func buildTaskToSave() -> VikunjaTask {
        VikunjaTask(
            id: task.id,
            title: task.title,
            description: task.description,
            done: task.done,
            dueDate: editDueDate,
            startDate: editStartDate,
            endDate: editEndDate,
            labels: task.labels,
            reminders: task.reminders,
            priority: task.priority,
            percentDone: task.percentDone,
            hexColor: task.hexColor,
            repeatAfter: taskRepeatAfter,
            repeatMode: taskRepeatMode,
            assignees: task.assignees,
            createdBy: task.createdBy,
            projectId: task.projectId,
            isFavorite: task.isFavorite,
            attachments: task.attachments,
            commentCount: task.commentCount,
            updatedAt: task.updatedAt,
            relations: task.relations
        )
    }

    /// Apply API response to local state, trigger sync, and notify parent.
    private func applyUpdatedTask(_ updatedTask: VikunjaTask) async throws {
        Log.app.debug("Task saved successfully")
        Log.app.debug("API response dates - start: \(updatedTask.startDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("API response dates - due: \(updatedTask.dueDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("API response dates - end: \(updatedTask.endDate?.description ?? "nil", privacy: .public)")
        Log.app.debug("API returned repeat: after=\(updatedTask.repeatAfter?.description ?? "nil", privacy: .public)")
        Log.app.debug("API returned repeat mode: \(updatedTask.repeatMode.displayName, privacy: .public)")

        // Update edit buffers (what the UI shows)
        editStartDate = updatedTask.startDate
        editDueDate   = updatedTask.dueDate
        editEndDate   = updatedTask.endDate
        editedDescription = updatedTask.description ?? ""

        // One-way calendar sync after save
        if settings.calendarSyncEnabled {
            Log.app.debug("Triggering one-way calendar sync after task update")
            calendarSync.setAPI(api)
            await calendarSync.syncAfterTaskUpdate()
        }

        // Update canonical task + repeat workaround state
        task = updatedTask
        taskRepeatAfter = updatedTask.repeatAfter
        taskRepeatMode  = updatedTask.repeatMode

        hasChanges = false
        isEditing  = false

        // Force view refresh + notify parent
        await MainActor.run { refreshID = UUID() }
        onUpdate?(task)
    }
}
