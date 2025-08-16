import SwiftUI

struct TaskAssigneeView: View {
    @Binding var task: VikunjaTask
    let api: VikunjaAPI
    let canManageUsers: Bool
    let isEditing: Bool

    @State private var showingUserSearch = false
    @State private var isUpdating = false
    @State private var error: String?

    var assignees: [VikunjaUser] { task.assignees ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            // Top “Assignees” row (matches your other rows)
            HStack {
                Text("Assignees")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                if assignees.isEmpty {
                    Text("None")
                        .foregroundColor(.secondary.opacity(0.6))
                } else {
                    Text("\(assignees.count)")
                        .foregroundColor(.secondary)
                }

                if isEditing && canManageUsers {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEditing && canManageUsers else { return }
                showingUserSearch = true
            }

            // Assigned users list (rows + inset dividers, no backgrounds)
            if !assignees.isEmpty {
                Divider().padding(.leading, 16)

                ForEach(Array(assignees.enumerated()), id: \.element.id) { index, user in
                    assigneeRow(user: user)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    if index < assignees.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }

            // Created by row
            if let createdBy = task.createdBy {
                Divider().padding(.leading, 16)

                HStack(spacing: 12) {
                    avatar(for: createdBy.displayName)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(createdBy.displayName)
                            .font(.subheadline)
                        Text("@\(createdBy.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView(api: api) { user in
                assignUser(user)
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            if let error { Text(error) }
        }
    }

    // MARK: - Row bits

    private func assigneeRow(user: VikunjaUser) -> some View {
        HStack(spacing: 12) {
            avatar(for: user.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isEditing && canManageUsers {
                Button {
                    removeAssignee(user)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .disabled(isUpdating)
                .opacity(isUpdating ? 0.6 : 1)
            }
        }
    }

    private func avatar(for name: String) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(.caption)
                    .foregroundColor(.accentColor)
            )
    }

    // MARK: - API actions

    private func assignUser(_ user: VikunjaUser) {
        if assignees.contains(where: { $0.id == user.id }) { return }
        isUpdating = true
        Task {
            do {
                let updated = try await api.assignUserToTask(taskId: task.id, userId: user.id)
                await MainActor.run {
                    task = updated
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isUpdating = false
                }
            }
        }
    }

    private func removeAssignee(_ user: VikunjaUser) {
        isUpdating = true
        Task {
            do {
                let updated = try await api.removeUserFromTask(taskId: task.id, userId: user.id)
                await MainActor.run {
                    task = updated
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isUpdating = false
                }
            }
        }
    }
}
#Preview {
    TaskAssigneeView(
        task: .constant(VikunjaTask(
            id: 1,
            title: "Sample Task",
            assignees: [
                VikunjaUser(id: 1, username: "john_doe", name: "John Doe", email: "john@example.com"),
                VikunjaUser(id: 2, username: "jane_smith", name: "Jane Smith")
            ],
            createdBy: VikunjaUser(id: 3, username: "creator", name: "Task Creator"),
            projectId: 1
        )),
        api: VikunjaAPI(
            config: .init(baseURL: URL(string: "https://example.com")!),
            tokenProvider: { nil }
        ),
        canManageUsers: true,
        isEditing: true // or false for read-only preview
    )
    .padding()
}
