// Features/Tasks/CommentsView.swift
import SwiftUI

struct CommentsView: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let commentCountManager: CommentCountManager?

    @State private var comments: [TaskComment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var newCommentText = ""
    @State private var isAddingComment = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments list
                if isLoading && comments.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        // Text("Loading comments...")
                        Text(String(localized: "comments.loading", comment: "Label shown when loading comments"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    emptyStateView
                } else {
                    commentsList
                }
                
                // Add comment section
                addCommentSection
            }
            // .navigationTitle("Comments")
            .navigationTitle(String(localized: "comments.title", comment: "Comments navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Done") {
                    Button(String(localized: "common.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadComments()
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                // Text("No Comments Yet")
                Text(String(localized: "comments.empty.title", comment: "Title shown when there are no comments"))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(String(localized: "comments.empty.subtitle", comment: "Title shown when there are no comments"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(comments) { comment in
                    CommentRowView(comment: comment, api: api, commentCountManager: commentCountManager, taskId: task.id) {
                        loadComments()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .refreshable {
            await loadCommentsAsync()
        }
    }
    
    private var addCommentSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                TextField(String(localized: "comments.add.placeholder", comment: "Placeholder for adding a comment"), text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: addComment) {
                    if isAddingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .background(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(18)
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    private func loadComments() {
        Task {
            await loadCommentsAsync()
        }
    }
    
    private func loadCommentsAsync() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedComments = try await api.getTaskComments(taskId: task.id)
            await MainActor.run {
                comments = fetchedComments.sorted { $0.created < $1.created }

                // Update comment count in manager
                commentCountManager?.updateCommentCount(for: task.id, count: comments.count)
            }
        } catch {
            await MainActor.run {
                // Handle common "no comments" scenarios gracefully
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("404") || errorMessage.contains("not found") ||
                   errorMessage.contains("no such file") || errorMessage.contains("missing") ||
                   errorMessage.contains("couldn't be read") {
                    // Task has no comments - this is normal, not an error
                    comments = []
                    #if DEBUG
                    Log.app.debug("CommentsView: Task id=\(task.id, privacy: .public) has no comments (404/not found)")
                    #endif
                } else {
                    // This is a real error that should be shown to the user
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func addComment() {
        let commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentText.isEmpty else { return }
        
        isAddingComment = true
        
        Task {
            do {
                let newComment = try await api.addTaskComment(taskId: task.id, comment: commentText)
                await MainActor.run {
                    comments.append(newComment)
                    comments.sort { $0.created < $1.created }
                    newCommentText = ""
                    isAddingComment = false

                    // Update comment count in manager
                    commentCountManager?.updateCommentCount(for: task.id, count: comments.count)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isAddingComment = false
                }
            }
        }
    }
}

struct CommentRowView: View {
    let comment: TaskComment
    let api: VikunjaAPI
    let commentCountManager: CommentCountManager?
    let taskId: Int
    let onDelete: () -> Void
    
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Author avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(comment.author.displayName.prefix(1).uppercased())
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(comment.author.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(comment.created, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .opacity(isDeleting ? 0.5 : 1.0)
                        .disabled(isDeleting)
                    }
                    
                    Text(verbatim: "@\(comment.author.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(comment.comment)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        // .confirmationDialog("Delete Comment", isPresented: $showingDeleteConfirmation) {
        .confirmationDialog(String(localized: "comments.delete.title", comment: "Delete comment dialog title"), isPresented: $showingDeleteConfirmation) {
            // Button("Delete", role: .destructive) {
            Button(String(localized: "common.delete", comment: "Delete button"), role: .destructive) {
                deleteComment()
            }
            Button(String(localized: "common.cancel", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(String(localized: "comments.delete.confirmation", comment: "Title for are you sure you want to delete this comment"))
        }
    }
    
    private func deleteComment() {
        isDeleting = true
        
        Task {
            do {
                try await api.deleteTaskComment(taskId: comment.id, commentId: comment.id)
                await MainActor.run {
                    onDelete()
                    isDeleting = false

                    // Update comment count in manager (decrement)
                    commentCountManager?.decrementCommentCount(for: taskId)
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // Could add error handling here
                }
            }
        }
    }
}

struct CommentsButtonView: View {
    let task: VikunjaTask
    let api: VikunjaAPI
    let commentCountManager: CommentCountManager?

    @State private var showingComments = false
    @State private var commentCount = 0
    @State private var isLoadingCount = false

    var body: some View {
        Button(action: {
            showingComments = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Text("Comments")
                    Text(String(localized: "comments.title", comment: "Title for comments"))
                        .font(.body)
                        .foregroundColor(.primary)

                    if isLoadingCount {
                        // Text("Loading...")
                        Text(String(localized: "common.loading.label", comment: "Label shown when loading"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(commentCount == 0 ? String(localized: "tasks.comments.none", comment: "No comments yet") : "\(commentCount) comment\(commentCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingComments) {
            CommentsView(task: task, api: api, commentCountManager: commentCountManager)
        }
        .onAppear {
            loadCommentCount()
        }
    }

    private func loadCommentCount() {
        isLoadingCount = true

        Task {
            do {
                let comments = try await api.getTaskComments(taskId: task.id)
                await MainActor.run {
                    commentCount = comments.count
                    isLoadingCount = false
                }
            } catch {
                await MainActor.run {
                    commentCount = 0
                    isLoadingCount = false
                }
            }
        }
    }
}

struct CommentBadge: View {
    let commentCount: Int

    var body: some View {
        if commentCount > 0 {
            Text(verbatim: "\(commentCount)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}

#if DEBUG
struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        let task = VikunjaTask(id: 1, title: "Sample Task")
        let api = VikunjaAPI(config: VikunjaConfig(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil })
        let commentCountManager = CommentCountManager(api: api)
        CommentsView(task: task, api: api, commentCountManager: commentCountManager)
    }
}
#endif
