import SwiftUI

struct RemindersEditorSheet: View {
    @State var task: VikunjaTask
    let api: VikunjaAPI
    let onUpdated: (VikunjaTask) -> Void
    let onClose: () -> Void
    @State private var error: String?
    @State private var newReminderDate: Date = Date()

    var body: some View {
        NavigationView {
            List {
                if let reminders = task.reminders, !reminders.isEmpty {
                    ForEach(reminders) { r in
                        HStack {
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                            Text(r.reminder.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Button(role: .destructive) { remove(r) } label: { Image(systemName: "trash") }
                        }
                    }
                } else {
                    Text(String(localized: "tasks.detail.reminders.none", comment: "No reminders")).foregroundColor(.secondary)
                }

                Text(String(localized: "common.add", comment: "Add"))
                    .font(.footnote).foregroundStyle(.secondary)
                DatePicker(String(localized: "tasks.reminder", comment: "Reminder"),
                            selection: $newReminderDate,
                            displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                Button { addReminder(date: newReminderDate) } label: {
                    SwiftUI.Label(String(localized: "tasks.details.reminders.add", comment: "Add reminder"),
                                    systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle(String(localized: "tasks.reminders.title", comment: "Reminders"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close", comment: "Close"), action: onClose)
                }
            }
            .alert(String(localized: "common.error"), isPresented: .constant(error != nil)) {
                Button(String(localized: "common.ok", comment: "OK")) { error = nil }
            } message: {
                if let error { Text(error) }
            }
        }
    }

    private func addReminder(date: Date) {
        Task {
            do {
                let updated = try await api.addReminderToTask(taskId: task.id, reminderDate: date)
                await MainActor.run { task = updated; onUpdated(updated) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    private func remove(_ reminder: Reminder) {
        guard let id = reminder.id else { return }
        Task {
            do {
                let updated = try await api.removeReminderFromTask(taskId: task.id, reminderId: id)
                await MainActor.run { task = updated; onUpdated(updated) }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}
