// Features/Projects/NewProjectView.swift
import SwiftUI

struct NewProjectView: View {
    @Binding var isPresented: Bool
    let api: VikunjaAPI
    
    @State private var projectTitle = ""
    @State private var projectDescription = ""
    @State private var isCreating = false
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    
                    TextField(String(localized: "projects.new.name", comment: "Project name field"), text: $projectTitle)
                        .textInputAutocapitalization(.words)
                    
                    TextField(String(localized: "common.descriptionOptional"), text: $projectDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    
                    Text(String(localized: "projects.new.details.title", comment: "Title for new project view"))
                }
                
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
            }
            
            .navigationTitle(String(localized: "projects.new.details.title", comment: "Title for new project view"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    
                    Button(String(localized: "common.create", comment: "Create button")) {
                        createProject()
                    }
                    .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
        .overlay {
            if isCreating {
                ProgressView(String(localized: "common.creating", comment: "Creating..."))
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
    }
    
    private func createProject() {
        isCreating = true
        error = nil
        
        Task {
            do {
                let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                _ = try await api.createProject(
                    title: trimmedTitle,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription
                )
                
                isCreating = false
                isPresented = false
            } catch {
                self.error = error.localizedDescription
                isCreating = false
            }
        }

    }
}

#Preview {
    NewProjectView(
        isPresented: .constant(true),
        api: VikunjaAPI(
            config: .init(baseURL: URL(string: "https://example.com")!), // swiftlint:disable:this force_unwrapping
            tokenProvider: { nil }
        )
    )
}
