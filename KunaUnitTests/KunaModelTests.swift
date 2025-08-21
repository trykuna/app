import XCTest
@testable import Kuna
import SwiftUI

final class KunaModelTests: XCTestCase {
    
    // MARK: - VikunjaTask Tests
    
    func testVikunjaTaskColorProperty() {
        // Test with custom hex color
        var task = createVikunjaTask(
            id: 1,
            title: "Test Task",
            hexColor: "FF5722",
            projectId: 1
        )
        
        XCTAssertEqual(task.color, Color(hex: "FF5722") ?? .blue)
        
        // Test with nil hex color (should default to blue)
        task.hexColor = nil
        XCTAssertEqual(task.color, Color(hex: "007AFF") ?? .blue)
    }
    
    func testVikunjaTaskHasCustomColor() {
        var task = createSampleTask()
        
        task.hexColor = "FF5722"
        XCTAssertTrue(task.hasCustomColor)
        
        task.hexColor = nil
        XCTAssertFalse(task.hasCustomColor)
    }
    
    func testVikunjaTaskHasAttachments() {
        var task = createSampleTask()
        
        // Test with nil attachments
        task.attachments = nil
        XCTAssertFalse(task.hasAttachments)
        
        // Test with empty attachments
        task.attachments = []
        XCTAssertFalse(task.hasAttachments)
        
        // Test with attachments - create a simple attachment via JSON decoding
        let attachmentJSON = """
        {"id": 1, "file_name": "test.pdf"}
        """.data(using: .utf8)!
        let attachment = try! JSONDecoder().decode(TaskAttachment.self, from: attachmentJSON)
        task.attachments = [attachment]
        XCTAssertTrue(task.hasAttachments)
    }
    
    func testVikunjaTaskHasComments() {
        var task = createSampleTask()
        
        // Test with nil comment count
        task.commentCount = nil
        XCTAssertFalse(task.hasComments)
        
        // Test with zero comments
        task.commentCount = 0
        XCTAssertFalse(task.hasComments)
        
        // Test with comments
        task.commentCount = 3
        XCTAssertTrue(task.hasComments)
    }
    
    func testVikunjaTaskEquatable() {
        let task1 = createSampleTask()
        let task2 = createSampleTask()
        
        XCTAssertEqual(task1, task2)
        
        let task3 = createVikunjaTask(
            id: 999,
            title: "Sample Task",
            description: "A sample task for testing",
            projectId: 1
        )
        XCTAssertNotEqual(task1, task3)
    }
    
    // MARK: - Project Tests
    
    func testProjectInitialization() {
        let projectJSON = """
        {"id": 1, "title": "Test Project", "description": "A test project"}
        """.data(using: .utf8)!
        
        let project = try! JSONDecoder().decode(Project.self, from: projectJSON)
        
        XCTAssertEqual(project.id, 1)
        XCTAssertEqual(project.title, "Test Project")
        XCTAssertEqual(project.description, "A test project")
    }
    
    func testProjectCodable() throws {
        let projectJSON = """
        {"id": 42, "title": "My Project", "description": "Project description"}
        """.data(using: .utf8)!
        
        let project = try JSONDecoder().decode(Project.self, from: projectJSON)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(project)
        XCTAssertNotNil(encoded)
        
        // Test decoding
        let decoded = try JSONDecoder().decode(Project.self, from: encoded)
        XCTAssertEqual(decoded.id, project.id)
        XCTAssertEqual(decoded.title, project.title)
        XCTAssertEqual(decoded.description, project.description)
    }
    
    // MARK: - Label Tests
    
    func testLabelInitialization() {
        let label = Label(
            id: 1,
            title: "urgent",
            hexColor: "FF0000",
            description: "High priority tasks"
        )
        
        XCTAssertEqual(label.id, 1)
        XCTAssertEqual(label.title, "urgent")
        XCTAssertEqual(label.hexColor, "FF0000")
    }
    
    func testLabelColor() {
        let label = Label(
            id: 1,
            title: "test",
            hexColor: "00FF00",
            description: nil
        )
        
        XCTAssertEqual(label.color, Color(hex: "00FF00") ?? .blue)
    }
    
    func testLabelCodable() throws {
        let label = Label(
            id: 1,
            title: "test-label",
            hexColor: "FF5722",
            description: "Test description"
        )
        
        let encoded = try JSONEncoder.vikunja.encode(label)
        let decoded = try JSONDecoder.vikunja.decode(Label.self, from: encoded)
        
        XCTAssertEqual(decoded.id, label.id)
        XCTAssertEqual(decoded.title, label.title)
        XCTAssertEqual(decoded.hexColor, label.hexColor)
    }
    
    // MARK: - VikunjaUser Tests
    
    func testVikunjaUserDisplayName() {
        // Test with name provided
        let userWithName = VikunjaUser(
            id: 1,
            username: "johndoe",
            name: "John Doe",
            email: "john@example.com"
        )
        XCTAssertEqual(userWithName.displayName, "John Doe")
        
        // Test with empty name
        let userWithEmptyName = VikunjaUser(
            id: 2,
            username: "janedoe",
            name: "",
            email: "jane@example.com"
        )
        XCTAssertEqual(userWithEmptyName.displayName, "janedoe")
        
        // Test with nil name
        let userWithoutName = VikunjaUser(
            id: 3,
            username: "bobsmith",
            name: nil,
            email: "bob@example.com"
        )
        XCTAssertEqual(userWithoutName.displayName, "bobsmith")
    }
    
    // MARK: - TaskAttachment Tests
    
    func testTaskAttachmentProperties() {
        let attachmentJSON = """
        {"id": 1, "file_name": "document.pdf"}
        """.data(using: .utf8)!
        
        let attachment = try! JSONDecoder().decode(TaskAttachment.self, from: attachmentJSON)
        
        XCTAssertEqual(attachment.id, 1)
        XCTAssertEqual(attachment.fileName, "document.pdf")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleTask() -> VikunjaTask {
        return createVikunjaTask(
            id: 1,
            title: "Sample Task",
            description: "A sample task for testing",
            projectId: 1
        )
    }
    
    private func createVikunjaTask(
        id: Int,
        title: String,
        description: String? = nil,
        done: Bool = false,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        labels: [Kuna.Label]? = nil,
        reminders: [Reminder]? = nil,
        priority: TaskPriority = .medium,
        percentDone: Double = 0.0,
        hexColor: String? = nil,
        repeatAfter: Int? = nil,
        repeatMode: RepeatMode = .afterAmount,
        assignees: [VikunjaUser]? = nil,
        createdBy: VikunjaUser? = nil,
        projectId: Int? = nil,
        isFavorite: Bool = false,
        attachments: [TaskAttachment]? = nil,
        commentCount: Int? = nil,
        updatedAt: Date? = nil,
        relations: [TaskRelation]? = nil
    ) -> VikunjaTask {
        return VikunjaTask(
            id: id,
            title: title,
            description: description,
            done: done,
            dueDate: dueDate,
            startDate: startDate,
            endDate: endDate,
            labels: labels,
            reminders: reminders,
            priority: priority,
            percentDone: percentDone,
            hexColor: hexColor,
            repeatAfter: repeatAfter,
            repeatMode: repeatMode,
            assignees: assignees,
            createdBy: createdBy,
            projectId: projectId,
            isFavorite: isFavorite,
            attachments: attachments,
            commentCount: commentCount,
            updatedAt: updatedAt,
            relations: relations
        )
    }
}

// MARK: - Test Extensions

// VikunjaTask is already Equatable in the main module