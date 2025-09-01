import SwiftUI

struct EditableDateRow: View {
    let title: String
    @Binding var date: Date?
    @Binding var hasTime: Bool
    let taskId: Int
    let isEditing: Bool
    @Binding var hasChanges: Bool
    var body: some View {
        let pickerBinding = Binding<Date>(
            get: { date ?? Date() },
            set: { newVal in
                date = hasTime ? newVal : Calendar.current.startOfDay(for: newVal)
                hasChanges = true
            }
        )
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                    .font(.body)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                if isEditing, date != nil {
                    Button {
                        date = nil
                        hasChanges = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if isEditing {
                if date != nil {
                    Picker("", selection: $hasTime) {
                        Text(String(localized: "common.date", comment: "Date")).tag(false)
                        Text(String(localized: "common.dateAndTime", comment: "Date & time")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: hasTime) { _, includeTime in
                        if var d = date {
                            if !includeTime { d = Calendar.current.startOfDay(for: d) }
                            date     = d
                            hasChanges = true
                        }
                    }
                    
                    DatePicker("",
                               selection: pickerBinding,
                               displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    // Stable identity across task & mode only
                    .id("\(taskId)-\(title)-\(hasTime ? "dt" : "d")")
                } else {
                    Button {
                        hasTime = false
                        date = Calendar.current.startOfDay(for: Date())
                        hasChanges = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.accentColor)
                            Text("add.title \(title)", comment: "Add title")
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Spacer()
                    if let d = date {
                        Text(d.formatted(date: .abbreviated,
                                         time: hasTime ? .shortened : .omitted))
                        .foregroundColor(.secondary)
                    } else {
                        Text(String(localized: "common.notSet", comment: "Not set"))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}
