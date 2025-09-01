import SwiftUI

struct SaveBar: View {
    let isUpdating: Bool
    let onCancel: () -> Void
    let onSave: () async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 16)
            HStack {
                Button(String(localized: "common.cancel", comment: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)
                
                Spacer()
                
                Button {
                    Task { await onSave() }
                } label: {
                    HStack(spacing: 8) {
                        if isUpdating { ProgressView().scaleEffect(0.8) }
                        Text(String(localized: "common.save", comment: "Save")).fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}