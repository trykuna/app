// Services/CommentCountManager.swift
import Foundation
import Combine

@MainActor
class CommentCountManager: ObservableObject {
    // Shared instance to avoid creating multiple managers
    static var shared: CommentCountManager?
    
    private let api: VikunjaAPI
    @Published private(set) var commentCounts: [Int: Int] = [:] // taskId -> commentCount
    private var loadingTasks: Set<Int> = []
    private let maxCachedCounts = 100 // Reasonable limit for comment counts
    
    init(api: VikunjaAPI) {
        self.api = api
    }
    
    static func getShared(api: VikunjaAPI) -> CommentCountManager {
        if let existing = shared {
            return existing
        }
        let new = CommentCountManager(api: api)
        shared = new
        return new
    }
    
    /// Get the cached comment count for a task, or nil if not loaded
    func getCommentCount(for taskId: Int) -> Int? {
        return commentCounts[taskId]
    }
    
    /// Load comment count for a task if not already loaded or loading
    func loadCommentCount(for taskId: Int) {
        // Don't load if already loaded or currently loading
        guard commentCounts[taskId] == nil && !loadingTasks.contains(taskId) else {
            return
        }
        
        loadingTasks.insert(taskId)
        
        Task {
            do {
                let count = try await api.getTaskCommentCount(taskId: taskId)
                await MainActor.run {
                    self.commentCounts[taskId] = count
                    self.loadingTasks.remove(taskId)
                    
                    // Trim cache if it gets too large
                    if self.commentCounts.count > self.maxCachedCounts {
                        self.trimCache()
                    }
                }
            } catch {
                await MainActor.run {
                    // Set to 0 on error to avoid repeated attempts
                    self.commentCounts[taskId] = 0
                    self.loadingTasks.remove(taskId)
                }
            }
        }
    }
    
    private func trimCache() {
        // Keep only the most recent entries
        let entriesToRemove = commentCounts.count - maxCachedCounts
        if entriesToRemove > 0 {
            let keysToRemove = commentCounts.keys.prefix(entriesToRemove)
            for key in keysToRemove {
                commentCounts.removeValue(forKey: key)
            }
            Log.app.debug("CommentCountManager: Trimmed cache, removed \(entriesToRemove) entries")
        }
    }
    
    /// Load comment counts for multiple tasks
    func loadCommentCounts(for taskIds: [Int]) {
        for taskId in taskIds {
            loadCommentCount(for: taskId)
        }
    }
    
    /// Update comment count for a task (when comments are added/removed)
    func updateCommentCount(for taskId: Int, count: Int) {
        commentCounts[taskId] = count
    }
    
    /// Increment comment count for a task (when a comment is added)
    func incrementCommentCount(for taskId: Int) {
        let currentCount = commentCounts[taskId] ?? 0
        commentCounts[taskId] = currentCount + 1
    }
    
    /// Decrement comment count for a task (when a comment is removed)
    func decrementCommentCount(for taskId: Int) {
        let currentCount = commentCounts[taskId] ?? 0
        commentCounts[taskId] = max(0, currentCount - 1)
    }
    
    /// Clear cached comment counts (useful when switching projects)
    func clearCache() {
        commentCounts.removeAll()
        loadingTasks.removeAll()
    }
    
    /// Clear comment count for a specific task (useful when task is deleted)
    func clearCommentCount(for taskId: Int) {
        commentCounts.removeValue(forKey: taskId)
        loadingTasks.remove(taskId)
    }
}
