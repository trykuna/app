// Services/CalendarSync/Debouncer.swift
import Foundation

final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }
    
    func call(after seconds: TimeInterval, _ block: @escaping () -> Void) {
        // Cancel any existing work item
        workItem?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem(block: block)
        self.workItem = workItem
        
        // Schedule execution
        queue.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
