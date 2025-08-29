import SwiftUI

// MARK: - Props that drive rendering of a row.
// We compare only the bits that change how the row looks.
struct TaskRowProps: Equatable {
    let t: VikunjaTask
    let showTaskColors: Bool
    let showDefaultColorBalls: Bool
    let showPriorityIndicators: Bool
    let showAttachmentIcons: Bool
    let showCommentCounts: Bool
    let showStartDate: Bool
    let showDueDate: Bool
    let showEndDate: Bool
    let commentCount: Int?

    static func == (lhs: TaskRowProps, rhs: TaskRowProps) -> Bool {
        // Reduce labels to a stable digest that doesn’t depend on reference identity
        func labelsKey(_ task: VikunjaTask) -> String {
            (task.labels ?? []).map { $0.title }.joined(separator: "|")
        }

        return
            String(describing: lhs.t.id) == String(describing: rhs.t.id) && // works whether id is Int, Int64, UUID, etc.
            lhs.t.done == rhs.t.done &&
            lhs.t.title == rhs.t.title &&
            String(describing: lhs.t.priority) == String(describing: rhs.t.priority) &&
            lhs.t.startDate == rhs.t.startDate &&
            lhs.t.dueDate == rhs.t.dueDate &&
            lhs.t.endDate == rhs.t.endDate &&
            labelsKey(lhs.t) == labelsKey(rhs.t) &&
            lhs.commentCount == rhs.commentCount &&

            // UI toggles
            lhs.showTaskColors == rhs.showTaskColors &&
            lhs.showDefaultColorBalls == rhs.showDefaultColorBalls &&
            lhs.showPriorityIndicators == rhs.showPriorityIndicators &&
            lhs.showAttachmentIcons == rhs.showAttachmentIcons &&
            lhs.showCommentCounts == rhs.showCommentCounts &&
            lhs.showStartDate == rhs.showStartDate &&
            lhs.showDueDate == rhs.showDueDate &&
            lhs.showEndDate == rhs.showEndDate
    }
}

// MARK: - The equatable content that actually renders the row.
// We ignore the closure/api in equality and only compare `props`.
struct TaskRowContent: View, Equatable {
    let props: TaskRowProps
    let api: VikunjaAPI
    let onToggle: (VikunjaTask) -> Void

    static func == (lhs: TaskRowContent, rhs: TaskRowContent) -> Bool {
        lhs.props == rhs.props
    }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button { onToggle(props.t) } label: {
                Image(systemName: props.t.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(props.t.done ? .green : .gray)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("task.row.toggle")

            // Color dot
            if props.showTaskColors && (props.t.hasCustomColor || props.showDefaultColorBalls) {
                Circle()
                    .fill(props.t.color) // assuming you already expose a Color on the model
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            }

            // Priority icon
            if props.showPriorityIndicators && props.t.priority != .unset {
                Image(systemName: props.t.priority.systemImage) // e.g. map enum -> symbol name
                    .foregroundColor(props.t.priority.color)    // e.g. map enum -> Color
                    .frame(width: 16, height: 16)
                    .accessibilityIdentifier("task.row.priority")
            }

            VStack(alignment: .leading, spacing: 6) {
                // Title + extras
                HStack(spacing: 8) {
                    Text(props.t.title)
                        .strikethrough(props.t.done)
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("task.row.title")

                    if props.showAttachmentIcons && props.t.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("task.row.attachment")
                    }

                    if props.showCommentCounts, let count = props.commentCount, count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "text.bubble")
                                .font(.caption2)
                            Text(verbatim: "\(count)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("task.row.comments")
                    }

                    Spacer(minLength: 0)
                }

                // Labels (avoid SwiftUI `Label` to not clash with your model type `Label`)
                if let labs = props.t.labels, !labs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(labs) { lab in
                                Text(lab.title)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(lab.color.opacity(0.2))
                                    .foregroundColor(lab.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .accessibilityIdentifier("task.row.labels")
                    }
                }

                // Dates row
                if (props.showStartDate && props.t.startDate != nil) ||
                   (props.showDueDate && props.t.dueDate != nil) ||
                   (props.showEndDate && props.t.endDate != nil) {
                    HStack(spacing: 8) {
                        if props.showStartDate, let start = props.t.startDate {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill").font(.caption2)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(start, style: .date).font(.caption2)
                                    Text(start, style: .time).font(.caption2)
                                }
                            }
                            .accessibilityIdentifier("task.row.startDate")
                        }
                        if props.showDueDate, let due = props.t.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock").font(.caption2)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(due, style: .date).font(.caption2)
                                    Text(due, style: .time).font(.caption2)
                                }
                            }
                            .accessibilityIdentifier("task.row.dueDate")
                        }
                        if props.showEndDate, let end = props.t.endDate {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.circle.fill").font(.caption2)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(end, style: .date).font(.caption2)
                                    Text(end, style: .time).font(.caption2)
                                }
                            }
                            .accessibilityIdentifier("task.row.endDate")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle()) // so tapping gaps still counts as a tap on the row
    }
}

// MARK: - Public row wrapper used by the list
struct TaskRowView: View {
    let props: TaskRowProps
    let api: VikunjaAPI
    let onToggle: (VikunjaTask) -> Void
    let onUpdate: ((VikunjaTask) -> Void)?
    
    init(props: TaskRowProps, api: VikunjaAPI, onToggle: @escaping (VikunjaTask) -> Void, onUpdate: ((VikunjaTask) -> Void)? = nil) {
        self.props = props
        self.api = api
        self.onToggle = onToggle
        self.onUpdate = onUpdate
    }

    var body: some View {
        // Keep the whole row tappable via NavigationLink...
        NavigationLink(destination: TaskDetailView(task: props.t, api: api, onUpdate: onUpdate)) {
            HStack(spacing: 8) {
                // Important: use EquatableView so SwiftUI can skip updates
                EquatableView(content: TaskRowContent(props: props, api: api, onToggle: onToggle))
                Spacer(minLength: 8)
                // ...and also expose a visible chevron with a stable identifier for UITests.
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("task.row.disclosure")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // keep platform styling minimal, preserves tap area
        .accessibilityIdentifier("task.row")
    }
}
