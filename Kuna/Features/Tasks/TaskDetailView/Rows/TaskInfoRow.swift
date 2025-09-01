import SwiftUI


struct TaskTitleRow: View {
    let isEditing: Bool
    @Binding var title: String
    @Binding var hasChanges: Bool
    
    var body: some View {
        HStack {
            Text(String(localized: "common.title", comment: "Title"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField(String(localized: "tasks.placeholder.title", comment: "Task title"), text: $title)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onChange(of: title) { _, _ in hasChanges = true }
            } else {
                Text(title).foregroundColor(.secondary).multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TaskDescriptionRow: View {
    let isEditing: Bool
    @Binding var editedDescription: String
    let taskDescription: String?
    @Binding var hasChanges: Bool
    
    var body: some View {
        HStack(alignment: .top) {
            Text(String(localized: "tasks.details.description.title", comment: "Description"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                TextField(String(localized: "tasks.detail.description.placeholder", comment: "Description"),
                          text: $editedDescription, axis: .vertical)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
                .lineLimit(1...4)
            } else {
                Text(taskDescription ?? "No description")
                    .foregroundColor(taskDescription == nil ? .secondary.opacity(0.6) : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

