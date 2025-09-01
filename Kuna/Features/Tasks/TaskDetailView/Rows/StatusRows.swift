import SwiftUI

struct TaskPriorityRow: View {
    let isEditing: Bool
    @Binding var priority: TaskPriority
    @Binding var hasChanges: Bool
    var body: some View {
        HStack {
            Text(String(localized: "tasks.detail.priority.title", comment: "Priority"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                Picker(String(localized: "tasks.detail.priority.title", comment: "Priority"), selection: $priority) {
                    ForEach(TaskPriority.allCases) { p in
                        HStack {
                            Image(systemName: p.systemImage).foregroundColor(p.color)
                            Text(p.displayName)
                        }.tag(p)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: priority) { _, _ in hasChanges = true }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: priority.systemImage).foregroundColor(priority.color).font(.body)
                    Text(priority.displayName).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TaskProgressRow: View {
    let isEditing: Bool
    @Binding var percentDone: Double
    @Binding var hasChanges: Bool
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "tasks.detail.progress.title", comment: "Progress"))
                    .font(.body).fontWeight(.medium)
                Spacer()
                Text(verbatim: "\(Int(percentDone * 100))%").foregroundColor(.secondary)
            }
            if isEditing {
                Slider(value: Binding(
                    get: { percentDone },
                    set: { v in percentDone = v; hasChanges = true }
                ), in: 0...1, step: 0.05)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
