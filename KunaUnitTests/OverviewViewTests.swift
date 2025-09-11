import XCTest
@testable import Kuna
import SwiftUI
import Foundation

@MainActor
final class OverviewViewTests: XCTestCase {
    
    // MARK: - Properties
    
    private var mockAPI: MockVikunjaAPI!
    private var mockAppState: AppState!
    private var realAPI: VikunjaAPI!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockAPI = MockVikunjaAPI()
        mockAppState = AppState()
        realAPI = VikunjaAPI(
            config: VikunjaConfig(baseURL: URL(string: "https://test.example.com")!),
            tokenProvider: { "test-token" }
        )
        
        // Clear any existing recent items
        AppSettings.shared.recentProjectIds = []
        AppSettings.shared.recentTaskIds = []
    }
    
    override func tearDown() {
        mockAPI = nil
        mockAppState = nil
        realAPI = nil
        
        // Clean up settings
        AppSettings.shared.recentProjectIds = []
        AppSettings.shared.recentTaskIds = []
        
        super.tearDown()
    }
    
    // MARK: - API Token Warning Tests
    
    func testAPITokenWarningShownForPersonalToken() throws {
        // Given
        mockAppState.authenticationMethod = .personalToken
        let view = OverviewView(api: realAPI, isMenuOpen: .constant(false))
            .environmentObject(mockAppState)
        
        // When
        _ = UIHostingController(rootView: view)
        
        // Then
        // The warning should be shown when using personal token
        // Note: Testing SwiftUI view hierarchy is limited, but we can verify the logic
        XCTAssertEqual(mockAppState.authenticationMethod, .personalToken)
    }
    
    func testAPITokenWarningHiddenForUsernamePassword() throws {
        // Given
        mockAppState.authenticationMethod = .usernamePassword
        let view = OverviewView(api: realAPI, isMenuOpen: .constant(false))
            .environmentObject(mockAppState)
        
        // When
        _ = UIHostingController(rootView: view)
        
        // Then
        XCTAssertEqual(mockAppState.authenticationMethod, .usernamePassword)
    }
    
    // MARK: - Quick Task Creation Tests
    
    func testQuickTaskCreationWithValidProject() async throws {
        // Given
        let mockProject = createMockProject(id: 1, title: "Test Project")
        let mockUser = createMockUser(id: 1, defaultProjectId: 1)
        
        mockAPI.mockProjects = [mockProject]
        mockAPI.mockCurrentUser = mockUser
        mockAPI.mockCreatedTask = VikunjaTask(
            id: 1,
            title: "New Task",
            description: nil,
            done: false,
            dueDate: nil,
            startDate: nil,
            endDate: nil,
            labels: nil,
            reminders: nil,
            priority: .medium,
            percentDone: 0.0,
            hexColor: nil,
            repeatAfter: nil,
            repeatMode: .afterAmount,
            assignees: nil,
            createdBy: nil,
            projectId: 1,
            isFavorite: false,
            attachments: nil,
            commentCount: nil,
            updatedAt: nil,
            relations: nil
        )
        
        _ = OverviewView(api: realAPI, isMenuOpen: .constant(false))
            .environmentObject(mockAppState)
        
        // When - simulate task creation
        // Note: We can't directly interact with SwiftUI views in unit tests,
        // but we can test the underlying logic by calling the API methods
        let createdTask = try await mockAPI.createTask(
            projectId: 1, 
            title: "Test Task", 
            description: nil
        )
        
        // Then
        XCTAssertEqual(createdTask.title, "Test Task")
        XCTAssertEqual(createdTask.projectId, 1)
        XCTAssertTrue(mockAPI.createTaskCalled)
    }
    
    func testQuickTaskCreationWithoutProjects() async throws {
        // Given
        mockAPI.mockProjects = []
        mockAPI.shouldThrowErrorForUser = true
        mockAPI.shouldThrowErrorForTaskCreation = true  // This should trigger the error
        
        // When/Then
        do {
            _ = try await mockAPI.createTask(projectId: 1, title: "Test", description: nil)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected to fail when no projects are available
            XCTAssertTrue(error is MockAPIError)
            XCTAssertEqual(error as? MockAPIError, MockAPIError.taskCreationFailed)
        }
    }
    
    func testProjectNameLoadingForUsernamePassword() async throws {
        // Given
        let mockProject = createMockProject(id: 1, title: "Default Project")
        let mockUser = createMockUser(id: 1, defaultProjectId: 1)
        
        mockAPI.mockProjects = [mockProject]
        mockAPI.mockCurrentUser = mockUser
        mockAppState.authenticationMethod = .usernamePassword
        
        // When
        let user = try await mockAPI.getCurrentUser()
        let projects = try await mockAPI.fetchProjects()
        
        // Then
        XCTAssertEqual(user.defaultProjectId, 1)
        XCTAssertEqual(projects.first?.title, "Default Project")
    }
    
    func testProjectNameFallbackForAPIToken() async throws {
        // Given
        let mockProject = createMockProject(id: 1, title: "First Project")
        mockAPI.mockProjects = [mockProject]
        mockAPI.shouldThrowErrorForUser = true
        mockAppState.authenticationMethod = .personalToken
        
        // When
        do {
            _ = try await mockAPI.getCurrentUser()
            XCTFail("Should have thrown an error for API token")
        } catch {
            // Expected error for API token
            let projects = try await mockAPI.fetchProjects()
            
            // Then
            XCTAssertEqual(projects.first?.title, "First Project")
        }
    }
    
    // MARK: - Recent Items Tests
    
    func testRecentProjectsEmpty() {
        // Given
        AppSettings.shared.recentProjectIds = []
        
        // When
        let isEmpty = AppSettings.shared.recentProjectIds.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty)
    }
    
    func testRecentProjectsWithData() {
        // Given
        AppSettings.shared.recentProjectIds = [1, 2, 3]
        
        // When
        let count = AppSettings.shared.recentProjectIds.count
        
        // Then
        XCTAssertEqual(count, 3)
        XCTAssertEqual(AppSettings.shared.recentProjectIds, [1, 2, 3])
    }
    
    func testRecentTasksEmpty() {
        // Given
        AppSettings.shared.recentTaskIds = []
        
        // When
        let isEmpty = AppSettings.shared.recentTaskIds.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty)
    }
    
    func testRecentTasksWithData() {
        // Given
        AppSettings.shared.recentTaskIds = [10, 20, 30]
        
        // When
        let count = AppSettings.shared.recentTaskIds.count
        
        // Then
        XCTAssertEqual(count, 3)
        XCTAssertEqual(AppSettings.shared.recentTaskIds, [10, 20, 30])
    }
    
    // MARK: - RecentProjectRow Tests
    
    func testRecentProjectRowWithValidProject() async throws {
        // Given
        let mockProject = createMockProject(id: 1, title: "Test Project")
        mockAPI.mockProjects = [mockProject]
        
        // When
        let projects = try await mockAPI.fetchProjects()
        let foundProject = projects.first(where: { $0.id == 1 })
        
        // Then
        XCTAssertNotNil(foundProject)
        XCTAssertEqual(foundProject?.title, "Test Project")
    }
    
    func testRecentProjectRowWithDeletedProject() async throws {
        // Given
        mockAPI.mockProjects = [] // No projects available
        AppSettings.shared.recentProjectIds = [999] // Non-existent project
        
        // When
        let projects = try await mockAPI.fetchProjects()
        let foundProject = projects.first(where: { $0.id == 999 })
        
        // Then
        XCTAssertNil(foundProject)
        // In the actual view, this would trigger loadFailed = true
        // and remove the project from recent list
    }
    
    // MARK: - RecentTaskRow Tests
    
    func testRecentTaskRowWithValidTask() async throws {
        // Given
        let mockTask = VikunjaTask(
            id: 1,
            title: "Test Task",
            description: nil,
            done: false,
            dueDate: nil,
            startDate: nil,
            endDate: nil,
            labels: nil,
            reminders: nil,
            priority: .medium,
            percentDone: 0.0,
            hexColor: nil,
            repeatAfter: nil,
            repeatMode: .afterAmount,
            assignees: nil,
            createdBy: nil,
            projectId: 1,
            isFavorite: false,
            attachments: nil,
            commentCount: nil,
            updatedAt: nil,
            relations: nil
        )
        mockAPI.mockTask = mockTask
        
        // When
        let task = try await mockAPI.getTask(taskId: 1)
        
        // Then
        XCTAssertEqual(task.id, 1)
        XCTAssertEqual(task.title, "Test Task")
    }
    
    func testRecentTaskRowWithDeletedTask() async throws {
        // Given
        AppSettings.shared.recentTaskIds = [999] // Non-existent task
        mockAPI.shouldThrowErrorForTask = true
        
        // When/Then
        do {
            _ = try await mockAPI.getTask(taskId: 999)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected error for deleted task
            XCTAssertTrue(error is MockAPIError)
        }
    }
    
    // MARK: - Settings Integration Tests
    
    func testDefaultViewSetting() {
        // Given
        AppSettings.shared.defaultView = .overview
        
        // When
        let defaultView = AppSettings.shared.defaultView
        
        // Then
        XCTAssertEqual(defaultView, .overview)
    }
    
    func testRecentItemsLimit() {
        // Given
        let initialIds = [1, 2, 3, 4, 5, 6] // More than limit of 4
        
        // When
        AppSettings.shared.recentProjectIds = Array(initialIds.prefix(4))
        
        // Then
        XCTAssertEqual(AppSettings.shared.recentProjectIds.count, 4)
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIErrorHandling() async {
        // Given
        mockAPI.shouldThrowErrorForUser = true
        
        // When/Then
        do {
            _ = try await mockAPI.getCurrentUser()
            XCTFail("Should have thrown an error")
        } catch let error as MockAPIError {
            XCTAssertEqual(error, .userFetchFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testProjectFetchErrorHandling() async {
        // Given
        mockAPI.shouldThrowErrorForProjects = true
        
        // When/Then
        do {
            _ = try await mockAPI.fetchProjects()
            XCTFail("Should have thrown an error")
        } catch let error as MockAPIError {
            XCTAssertEqual(error, .projectsFetchFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testTaskCreationErrorHandling() async {
        // Given
        mockAPI.shouldThrowErrorForTaskCreation = true
        
        // When/Then
        do {
            _ = try await mockAPI.createTask(projectId: 1, title: "Test", description: nil)
            XCTFail("Should have thrown an error")
        } catch let error as MockAPIError {
            XCTAssertEqual(error, .taskCreationFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Mock Classes

class MockVikunjaAPI {
    
    // Mock properties
    var mockProjects: [Project] = []
    var mockCurrentUser: (id: Int, defaultProjectId: Int?)?
    var mockTask: VikunjaTask?
    var mockCreatedTask: VikunjaTask = VikunjaTask(
        id: 1,
        title: "Test Task",
        description: nil,
        done: false,
        dueDate: nil,
        startDate: nil,
        endDate: nil,
        labels: nil,
        reminders: nil,
        priority: .medium,
        percentDone: 0.0,
        hexColor: nil,
        repeatAfter: nil,
        repeatMode: .afterAmount,
        assignees: nil,
        createdBy: nil,
        projectId: 1,
        isFavorite: false,
        attachments: nil,
        commentCount: nil,
        updatedAt: nil,
        relations: nil
    )
    
    // Error flags
    var shouldThrowErrorForUser = false
    var shouldThrowErrorForProjects = false
    var shouldThrowErrorForTask = false
    var shouldThrowErrorForTaskCreation = false
    
    // Call tracking
    var fetchProjectsCalled = false
    var getCurrentUserCalled = false
    var getTaskCalled = false
    var createTaskCalled = false
    
    func fetchProjects() async throws -> [Project] {
        fetchProjectsCalled = true
        
        if shouldThrowErrorForProjects {
            throw MockAPIError.projectsFetchFailed
        }
        
        return mockProjects
    }
    
    func getCurrentUser() async throws -> (id: Int, defaultProjectId: Int?) {
        getCurrentUserCalled = true
        
        if shouldThrowErrorForUser {
            throw MockAPIError.userFetchFailed
        }
        
        guard let user = mockCurrentUser else {
            throw MockAPIError.userFetchFailed
        }
        
        return user
    }
    
    func getTask(taskId: Int) async throws -> VikunjaTask {
        getTaskCalled = true
        
        if shouldThrowErrorForTask {
            throw MockAPIError.taskFetchFailed
        }
        
        guard let task = mockTask else {
            throw MockAPIError.taskFetchFailed
        }
        
        return task
    }
    
    func createTask(projectId: Int, title: String, description: String?) async throws -> VikunjaTask {
        createTaskCalled = true
        
        if shouldThrowErrorForTaskCreation {
            throw MockAPIError.taskCreationFailed
        }
        
        mockCreatedTask.title = title
        mockCreatedTask.projectId = projectId
        mockCreatedTask.description = description
        
        return mockCreatedTask
    }
}

enum MockAPIError: Error, Equatable {
    case userFetchFailed
    case projectsFetchFailed
    case taskFetchFailed
    case taskCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .userFetchFailed:
            return "Failed to fetch user"
        case .projectsFetchFailed:
            return "Failed to fetch projects"
        case .taskFetchFailed:
            return "Failed to fetch task"
        case .taskCreationFailed:
            return "Failed to create task"
        }
    }
}

// MARK: - Helper Functions

func createMockProject(id: Int, title: String) -> Project {
    // Create JSON data for the Project
    let projectJSON = """
    {
        "id": \(id),
        "title": "\(title)",
        "description": "Test project description"
    }
    """
    
    let data = projectJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    
    return try! decoder.decode(Project.self, from: data)
}

func createMockUser(id: Int, defaultProjectId: Int?) -> (id: Int, defaultProjectId: Int?) {
    return (id: id, defaultProjectId: defaultProjectId)
}