// Features/Labels/CreateLabelView.swift
import SwiftUI

struct CreateLabelView: View {
    let viewModel: LabelsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedColor = Color.blue
    @State private var isCreating = false
    
    @FocusState private var titleFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        // Preview
                        labelPreview
                        
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            // Text("Label Name")
                            Text(String(localized: "create_label_title_label", comment: "Label for label name field"))
                                .font(.headline)
                            
                            ZStack(alignment: .leading) {
                                if title.isEmpty {
                                    // Text("Enter label name")
                                    Text(String(localized: "create_label_title_placeholder", comment: "Placeholder for label name field"))
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
                            // Text("Color")
                            Text(String(localized: "create_label_colour_label", comment: "Label for colour picker"))
                                .font(.headline)
                            
                            HStack {
                                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 44, height: 44)
                                
                                // Text("Tap to choose a color")
                                Text(String(localized: "create_label_colour_tap_label", comment: "Label for colour picker"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        
                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            // Text("Description (Optional)")
                            Text(String(localized: "create_label_description_label", comment: "Label for description field"))
                                .font(.headline)
                            
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    // Text("Add a description for this label")
                                    Text(String(localized: "create_label_description_placeholder", comment: "Placeholder for description field"))
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
            .navigationTitle(String(localized: "create_label_title", comment: "Title for create label view"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createLabel()
                    }
                    .disabled(title.isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                titleFocused = true
            }
        }
    }
    
    private var labelPreview: some View {
        VStack(spacing: 8) {
            // Text("Preview")
            Text(String(localized: "create_label_preview_label", comment: "Label for label preview"))
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
    
    private func createLabel() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        
        Task {
            let hexColor = selectedColor.toHex()
            let desc = description.isEmpty ? nil : description
            
            let success = await viewModel.createLabel(
                title: title,
                hexColor: hexColor,
                description: desc
            )
            
            isCreating = false
            
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    CreateLabelView(viewModel: LabelsViewModel(api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil })))
}
