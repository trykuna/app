import SwiftUI

struct TaskRepeatRow: View {
    let isEditing: Bool
    let repeatAfter: Int?
    let displayText: String
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(String(localized: "tasks.details.repeat.title", comment: "Repeat"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if let after = repeatAfter, after > 0 {
                Text(displayText).foregroundColor(.secondary)
            } else {
                Text(String(localized: "common.never", comment: "Never"))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if isEditing { onTap() } }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
