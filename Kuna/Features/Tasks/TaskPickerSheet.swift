// Features/Tasks/TaskPickerSheet.swift
import SwiftUI

struct TaskPickerSheet: View {
    let api: VikunjaAPI
    let onPicked: (VikunjaTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [VikunjaTask] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField(String(localized: "tasks.search.placeholder", comment: "Search tasks..."), text: $query)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit { search() }
                    if !query.isEmpty {
                        Button { query = "" ; results = []; hasSearched = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding()

                if let error = error {
                    VStack(spacing: 8) {
                        Text(error).font(.caption).foregroundColor(.red)
                        // Button("Retry", action: search).font(.caption)
                        Button(String(localized: "common.retry", comment: "Retry button"), action: search).font(.caption)
                    }.padding()
                }

                if isSearching {
                    ProgressView().padding()
                } else if results.isEmpty && hasSearched {
                    // Text("No tasks found").foregroundColor(.secondary).padding()
                    Text(String(localized: "tasks.search.noResults", comment: "No tasks found")).foregroundColor(.secondary).padding()
                } else if !hasSearched {
                    VStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass").font(.system(size: 40)).foregroundColor(.secondary)
                        // Text("Search for tasks")
                        Text(String(localized: "tasks.search.title", comment: "Title for search for tasks"))
                            .font(.headline)
                        // Text("Type part of a title or description to find a task")
                        Text(String(localized: "tasks.search.description", comment: "Type part of a title or description to find a task"))
                            .foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(results) { t in
                        Button {
                            onPicked(t)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(t.done ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).lineLimit(1)
                                    HStack(spacing: 8) {
                                        if let projectId = t.projectId { Text(verbatim: "#\(projectId)").font(.caption).foregroundColor(.secondary) }
                                        if let due = t.dueDate { Text(due, style: .date).font(.caption).foregroundColor(.secondary) }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer(minLength: 0)
            }
            // .navigationTitle("Pick Task")
            .navigationTitle(String(localized: "tasks.picker.navigationTitle", comment: "Pick task navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarLeading) { Button(String(localized: "common.cancel", comment: "Cancel button")) { dismiss() } }
                // ToolbarItem(placement: .navigationBarTrailing) { Button("Search") { search() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button(String(localized: "common.search", comment: "Search button")) { search() } }
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true; error = nil
        Task {
            do {
                let found = try await api.searchTasks(query: q)
                await MainActor.run {
                    results = found
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

