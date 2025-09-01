import SwiftUI

typealias AsyncTask = Task

extension TaskDetailView {
    
    var sheetModifiers: some View {
        EmptyView()
            .sheet(isPresented: $showingLabelPicker) {
                labelPickerSheet
            }
            .sheet(isPresented: $showingRemindersEditor) {
                remindersEditorSheet
            }
            .sheet(isPresented: $showingRepeatEditor) {
                repeatEditorSheet
            }
    }
    
    private var labelPickerSheet: some View {
        LabelPickerSheet(
            availableLabels: availableLabels,
            initialSelected: Set(task.labels?.map { $0.id } ?? []),
            onCommit: { newSelected in
                AsyncTask {
                    let current = Set(task.labels?.map { $0.id } ?? [])
                    let toAdd = newSelected.subtracting(current)
                    let toRemove = current.subtracting(newSelected)
                    do {
                        for id in toAdd { task = try await api.addLabelToTask(taskId: task.id, labelId: id) }
                        for id in toRemove { task = try await api.removeLabelFromTask(taskId: task.id, labelId: id) }
                        onUpdate?(task)
                        if settings.calendarSyncEnabled && hasTaskDates {
                            await syncTaskToCalendarDirect(task)
                        }
                    } catch {
                        updateError = error.localizedDescription
                    }
                    showingLabelPicker = false
                }
            },
            onCancel: { showingLabelPicker = false }
        )
    }
    
    private var remindersEditorSheet: some View {
        RemindersEditorSheet(
            task: task,
            api: api,
            onUpdated: { updated in
                task = updated
                onUpdate?(updated)
            },
            onClose: { showingRemindersEditor = false }
        )
    }
    
    private var repeatEditorSheet: some View {
        RepeatEditorSheet(
            repeatAfter: taskRepeatAfter,  // Use workaround state
            repeatMode: taskRepeatMode,     // Use workaround state
            onCommit: { newAfter, newMode in
                Log.app.debug("RepeatEditorSheet onCommit - newAfter: \(newAfter?.description ?? "nil", privacy: .public)")
                Log.app.debug("RepeatEditorSheet onCommit - newMode: \(newMode.displayName, privacy: .public)")
                Log.app.debug("BEFORE - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
                Log.app.debug("BEFORE - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")
                
                // WORKAROUND: Update the separate state variables
                taskRepeatAfter = newAfter
                taskRepeatMode = newMode
                
                Log.app.debug("AFTER - taskRepeatAfter: \(taskRepeatAfter?.description ?? "nil", privacy: .public)")
                Log.app.debug("AFTER - taskRepeatMode: \(taskRepeatMode.displayName, privacy: .public)")
                
                // Also try to update task (even though we know it fails)
                task.repeatAfter = newAfter
                task.repeatMode = newMode
                Log.app.debug("Task (wrong) - repeatAfter: \(task.repeatAfter?.description ?? "nil", privacy: .public)")
                Log.app.debug("Task (wrong) - repeatMode: \(task.repeatMode.displayName, privacy: .public)")
                
                hasChanges = true
                showingRepeatEditor = false
            },
            onCancel: { showingRepeatEditor = false }
        )
    }
}