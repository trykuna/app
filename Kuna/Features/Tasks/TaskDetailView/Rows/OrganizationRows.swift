import SwiftUI

struct TaskLabelsRow: View {
    let isEditing: Bool
    let labels: [Label]?                 // pass task.labels
    var onTap: (() -> Void)? = nil       // open label picker

    var body: some View {
        HStack(alignment: .center) {
            Text(String(localized: "labels.title", comment: "Labels"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if let labels, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(3)) { label in
                        Text(label.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(label.color.opacity(0.2))
                            .foregroundColor(label.color)
                            .cornerRadius(10)
                    }
                    if labels.count > 3 {
                        Text(verbatim: "+\(labels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
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
        .onTapGesture { if isEditing { onTap?() } }
    }
}

struct TaskColorRow: View {
    let isEditing: Bool
    @Binding var selectedHexColor: String?   // bind to task.hexColor
    let displayColor: Color                  // pass task.color for read-only
    let presetColors: [Color]                // pass your preset array
    @Binding var hasChanges: Bool

    var body: some View {
        HStack {
            Text(String(localized: "common.colour", comment: "Colour"))
                .font(.body).fontWeight(.medium)
            Spacer()
            if isEditing {
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        let hex = color.toHex()                // uses your existing extension
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(
                                    (hex == selectedHexColor) ? Color.primary : Color.clear,
                                    lineWidth: 2
                                )
                            )
                            .onTapGesture {
                                selectedHexColor = hex
                                hasChanges = true
                            }
                    }
                }
            } else {
                Circle()
                    .fill(displayColor)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
