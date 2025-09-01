import SwiftUI

struct LabelPickerSheet: View {
    let availableLabels: [Label]
    @State var selected: Set<Int>
    let onCommit: (Set<Int>) -> Void
    let onCancel: () -> Void

    init(availableLabels: [Label],
         initialSelected: Set<Int>,
         onCommit: @escaping (Set<Int>) -> Void,
         onCancel: @escaping () -> Void) {
        self.availableLabels = availableLabels
        self._selected = State(initialValue: initialSelected)
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(availableLabels) { label in
                    HStack {
                        Circle().fill(label.color).frame(width: 12, height: 12)
                        Text(label.title)
                        Spacer()
                        if selected.contains(label.id) { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(label.id) { selected.remove(label.id) } else { selected.insert(label.id) }
                    }
                }
            }
            .navigationTitle(String(localized: "tasks.labels.select", comment: "Select labels"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", comment: "Done")) { onCommit(selected) }
                }
            }
        }
    }
}
