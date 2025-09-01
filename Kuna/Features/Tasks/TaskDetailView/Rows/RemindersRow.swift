import SwiftUI

struct TaskRemindersRow: View {
    let isEditing: Bool
    let remindersCount: Int
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(String(localized: "tasks.details.reminders.title", comment: "Reminders"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if remindersCount > 0 {
                Text(verbatim: "\(remindersCount)")
                    .foregroundColor(.secondary)
            } else {
                Text(String(localized: "common.none", comment: "None"))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { if isEditing { onTap() } }
    }
}
