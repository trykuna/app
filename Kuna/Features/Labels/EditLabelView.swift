// Features/Labels/EditLabelView.swift
import SwiftUI

struct EditLabelView: View {
    let viewModel: LabelsViewModel
    let label: Label
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var selectedColor: Color
    @State private var isUpdating = false
    
    @FocusState private var titleFocused: Bool
    
    init(viewModel: LabelsViewModel, label: Label) {
        self.viewModel = viewModel
        self.label = label
        _title = State(initialValue: label.title)
        _description = State(initialValue: label.description ?? "")
        _selectedColor = State(initialValue: label.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        // Preview
                        labelPreview
                        
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Label Name")
                                .font(.headline)
                            
                            ZStack(alignment: .leading) {
                                if title.isEmpty {
                                    Text("Enter label name")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .textSelection(.disabled)
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: $title)
                                    .focused($titleFocused)
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.next)
                            }
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        // Color picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.headline)
                            
                            HStack {
                                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 44, height: 44)
                                
                                Text("Tap to choose a color")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        
                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.headline)
                            
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Add a description for this label")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .textSelection(.disabled)
                                        .allowsHitTesting(false)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: $description)
                                    .frame(minHeight: 80)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateLabel()
                    }
                    .disabled(title.isEmpty || isUpdating || !hasChanges)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var labelPreview: some View {
        VStack(spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(title.isEmpty ? "Label Preview" : title)
                .font(.body)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedColor.opacity(0.2))
                .foregroundColor(selectedColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedColor, lineWidth: 1)
                )
        }
    }
    
    private var hasChanges: Bool {
        title != label.title ||
        description != (label.description ?? "") ||
        selectedColor.toHex() != (label.hexColor ?? "007AFF")
    }
    
    private func updateLabel() {
        guard !title.isEmpty, hasChanges else { return }
        
        isUpdating = true
        
        Task {
            let hexColor = selectedColor.toHex()
            let desc = description.isEmpty ? nil : description
            
            let success = await viewModel.updateLabel(
                label,
                title: title,
                hexColor: hexColor,
                description: desc
            )
            
            isUpdating = false
            
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    EditLabelView(
        viewModel: LabelsViewModel(api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil })),
        label: Label(id: 1, title: "Sample Label", hexColor: "007AFF", description: "A sample label")
    )
}
