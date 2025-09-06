import SwiftUI

struct CalendarSyncStatusRow: View {
    let hasTaskDates: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "calendar").foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                if hasTaskDates {
                    Text(String(localized: "tasks.sync.autoSave", comment: "Auto sync on save"))
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text(String(localized: "tasks.sync.needBothDates", comment: "Needs both start and end dates"))
                        .font(.caption).foregroundColor(.orange)
                }
            }
            Spacer()
            Image(systemName: hasTaskDates ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(hasTaskDates ? .green : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
