// Features/Users/UserSearchView.swift
import SwiftUI

struct UserSearchView: View {
    let api: VikunjaAPI
    let onUserSelected: (VikunjaUser) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [VikunjaUser] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var hasSearched = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField(String(localized: "users.search.placeholder", comment: "Search users..."), text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                searchUsers()
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                hasSearched = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    
                    if !searchText.isEmpty && !isSearching {
                        Button(action: searchUsers) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("users.search.prompt \(searchText)",
                                     comment: "Prompt in user search view. Placeholder is the current search text")
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // Results
                if isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                        // Text("Searching users...")
                        Text(String(localized: "users.search.searching", comment: "Label shown when searching users"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasSearched && searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        // Text("No users found")
                        Text(String(localized: "users.search.noResults.title", comment: "Title for no users found"))
                            .font(.headline)
                        
                        // Text("Try a different search term")
                        Text(String(localized: "users.search.noResults.suggestion", comment: "Try a different search term"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        // Text("Search for Users")
                        Text(String(localized: "users.search.title", comment: "Title for search for users"))
                            .font(.headline)
                        
                        // Text("Enter a username or name to find users you can assign to tasks")
                        Text(String(localized: "users.search.description", comment: "Enter a username or name to find users you can assign to tasks"))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(searchResults) { user in
                        UserRow(user: user) {
                            onUserSelected(user)
                            dismiss()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            // .navigationTitle("Find Users")
            .navigationTitle(String(localized: "users.find.title", comment: "Find users navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "common.error"), isPresented: .constant(error != nil)) {
                // Button("OK") {
                Button(String(localized: "common.ok", comment: "OK button")) {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func searchUsers() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        error = nil
        
        Task {
            do {
                let results = try await api.searchUsers(query: searchText)
                await MainActor.run {
                    searchResults = results
                    hasSearched = true
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

struct UserRow: View {
    let user: VikunjaUser
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(verbatim: "@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    UserSearchView(
        api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil }), // swiftlint:disable:this force_unwrapping
        onUserSelected: { _ in }
    )
}
