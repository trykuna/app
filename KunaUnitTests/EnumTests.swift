import XCTest
@testable import Kuna
import SwiftUI

final class EnumTests: XCTestCase {
    
    // MARK: - TaskPriority Tests
    
    func testTaskPriorityRawValues() {
        XCTAssertEqual(TaskPriority.unset.rawValue, 0)
        XCTAssertEqual(TaskPriority.low.rawValue, 1)
        XCTAssertEqual(TaskPriority.medium.rawValue, 2)
        XCTAssertEqual(TaskPriority.high.rawValue, 3)
        XCTAssertEqual(TaskPriority.urgent.rawValue, 4)
        XCTAssertEqual(TaskPriority.doNow.rawValue, 5)
    }
    
    func testTaskPriorityColors() {
        XCTAssertEqual(TaskPriority.unset.color, .gray)
        XCTAssertEqual(TaskPriority.low.color, .blue)
        XCTAssertEqual(TaskPriority.medium.color, .yellow)
        XCTAssertEqual(TaskPriority.high.color, .orange)
        XCTAssertEqual(TaskPriority.urgent.color, .red)
        XCTAssertEqual(TaskPriority.doNow.color, .purple)
    }
    
    func testTaskPrioritySystemImages() {
        XCTAssertEqual(TaskPriority.unset.systemImage, "minus")
        XCTAssertEqual(TaskPriority.low.systemImage, "arrow.down")
        XCTAssertEqual(TaskPriority.medium.systemImage, "minus")
        XCTAssertEqual(TaskPriority.high.systemImage, "arrow.up")
        XCTAssertEqual(TaskPriority.urgent.systemImage, "exclamationmark")
        XCTAssertEqual(TaskPriority.doNow.systemImage, "exclamationmark.2")
    }
    
    func testTaskPriorityAllCases() {
        let expectedCount = 6
        XCTAssertEqual(TaskPriority.allCases.count, expectedCount)
        
        // Ensure all expected cases are present
        XCTAssertTrue(TaskPriority.allCases.contains(.unset))
        XCTAssertTrue(TaskPriority.allCases.contains(.low))
        XCTAssertTrue(TaskPriority.allCases.contains(.medium))
        XCTAssertTrue(TaskPriority.allCases.contains(.high))
        XCTAssertTrue(TaskPriority.allCases.contains(.urgent))
        XCTAssertTrue(TaskPriority.allCases.contains(.doNow))
    }
    
    func testTaskPriorityIdentifiable() {
        // Test that each priority has a unique identifier
        let ids = TaskPriority.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All TaskPriority cases should have unique IDs")
        
        // Test specific ID values match raw values
        XCTAssertEqual(TaskPriority.medium.id, TaskPriority.medium.rawValue)
        XCTAssertEqual(TaskPriority.urgent.id, TaskPriority.urgent.rawValue)
    }
    
    func testTaskPriorityCodable() throws {
        let priority = TaskPriority.high
        
        // Test encoding
        let encoded = try JSONEncoder().encode(priority)
        XCTAssertNotNil(encoded)
        
        // Test decoding
        let decoded = try JSONDecoder().decode(TaskPriority.self, from: encoded)
        XCTAssertEqual(decoded, priority)
        
        // Test decoding from raw value
        let rawData = "3".data(using: .utf8)!
        let decodedFromRaw = try JSONDecoder().decode(TaskPriority.self, from: rawData)
        XCTAssertEqual(decodedFromRaw, .high)
    }
    
    // MARK: - RepeatMode Tests
    
    func testRepeatModeRawValues() {
        XCTAssertEqual(RepeatMode.afterAmount.rawValue, 0)
        XCTAssertEqual(RepeatMode.monthly.rawValue, 1)
        XCTAssertEqual(RepeatMode.fromCurrentDate.rawValue, 2)
    }
    
    func testRepeatModeAllCases() {
        let expectedCount = 3
        XCTAssertEqual(RepeatMode.allCases.count, expectedCount)
        
        XCTAssertTrue(RepeatMode.allCases.contains(.afterAmount))
        XCTAssertTrue(RepeatMode.allCases.contains(.monthly))
        XCTAssertTrue(RepeatMode.allCases.contains(.fromCurrentDate))
    }
    
    func testRepeatModeIdentifiable() {
        let ids = RepeatMode.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All RepeatMode cases should have unique IDs")
        
        XCTAssertEqual(RepeatMode.afterAmount.id, RepeatMode.afterAmount.rawValue)
        XCTAssertEqual(RepeatMode.monthly.id, RepeatMode.monthly.rawValue)
    }
    
    // MARK: - AuthenticationMethod Tests
    
    func testAuthenticationMethodRawValues() {
        XCTAssertEqual(AuthenticationMethod.usernamePassword.rawValue, "Username & Password")
        XCTAssertEqual(AuthenticationMethod.personalToken.rawValue, "Personal API Token")
    }
    
    func testAuthenticationMethodDescriptions() {
        XCTAssertEqual(AuthenticationMethod.usernamePassword.description, "Username & Password")
        XCTAssertEqual(AuthenticationMethod.personalToken.description, "Personal API Token")
    }
    
    func testAuthenticationMethodSystemImages() {
        XCTAssertEqual(AuthenticationMethod.usernamePassword.systemImage, "person.circle")
        XCTAssertEqual(AuthenticationMethod.personalToken.systemImage, "key")
    }
    
    func testAuthenticationMethodAllCases() {
        let expectedCount = 2
        XCTAssertEqual(AuthenticationMethod.allCases.count, expectedCount)
        
        XCTAssertTrue(AuthenticationMethod.allCases.contains(.usernamePassword))
        XCTAssertTrue(AuthenticationMethod.allCases.contains(.personalToken))
    }
    
    // MARK: - TaskRelationKind Tests
    
    func testTaskRelationKindRawValues() {
        XCTAssertEqual(TaskRelationKind.subtask.rawValue, "subtask")
        XCTAssertEqual(TaskRelationKind.parenttask.rawValue, "parenttask")
        XCTAssertEqual(TaskRelationKind.related.rawValue, "related")
        XCTAssertEqual(TaskRelationKind.duplicateof.rawValue, "duplicateof")
        XCTAssertEqual(TaskRelationKind.duplicates.rawValue, "duplicates")
        XCTAssertEqual(TaskRelationKind.blocking.rawValue, "blocking")
        XCTAssertEqual(TaskRelationKind.blocked.rawValue, "blocked")
        XCTAssertEqual(TaskRelationKind.precedes.rawValue, "precedes")
        XCTAssertEqual(TaskRelationKind.follows.rawValue, "follows")
        XCTAssertEqual(TaskRelationKind.copiedfrom.rawValue, "copiedfrom")
        XCTAssertEqual(TaskRelationKind.copiedto.rawValue, "copiedto")
    }
    
    func testTaskRelationKindAllCases() {
        let expectedCount = 12
        XCTAssertEqual(TaskRelationKind.allCases.count, expectedCount)
    }
    
    func testTaskRelationKindIdentifiable() {
        let ids = TaskRelationKind.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All TaskRelationKind cases should have unique IDs")
    }
    
    func testTaskRelationKindCodable() throws {
        let relation = TaskRelationKind.blocking
        
        // Test encoding
        let encoded = try JSONEncoder().encode(relation)
        let encodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(encodedString, "\"blocking\"")
        
        // Test decoding
        let decoded = try JSONDecoder().decode(TaskRelationKind.self, from: encoded)
        XCTAssertEqual(decoded, relation)
    }
    
    // MARK: - APIError Tests
    
    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIError.badURL.errorDescription, "Bad URL")
        XCTAssertEqual(APIError.http(404).errorDescription, "HTTP 404")
        XCTAssertEqual(APIError.decoding.errorDescription, "Decoding failed")
        XCTAssertEqual(APIError.missingToken.errorDescription, "No auth token")
        XCTAssertEqual(APIError.totpRequired.errorDescription, "TOTP code required")
        XCTAssertEqual(APIError.other("Custom error").errorDescription, "Custom error")
    }
    
    func testAPIErrorEquality() {
        XCTAssertEqual(APIError.badURL, APIError.badURL)
        XCTAssertEqual(APIError.http(500), APIError.http(500))
        XCTAssertNotEqual(APIError.http(404), APIError.http(500))
        XCTAssertEqual(APIError.other("test"), APIError.other("test"))
        XCTAssertNotEqual(APIError.other("test1"), APIError.other("test2"))
    }
    
    // MARK: - Edge Cases and Error Conditions
    
    func testInvalidEnumDecoding() {
        // Test decoding invalid TaskPriority values
        let invalidPriorityData = "99".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TaskPriority.self, from: invalidPriorityData))
        
        // Test decoding invalid TaskRelationKind - should fall back to .unknown rather than throw
        let invalidRelationData = "\"invalid_relation\"".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(TaskRelationKind.self, from: invalidRelationData)
        XCTAssertEqual(decoded, .unknown)
    }
    
    func testEnumHashable() {
        // Test that enums can be used in Sets and Dictionaries
        let prioritySet: Set<TaskPriority> = [.low, .medium, .high, .medium]
        XCTAssertEqual(prioritySet.count, 3) // .normal should only appear once
        
        let relationDict: [TaskRelationKind: String] = [
            .blocking: "blocks",
            .blocked: "blocked by"
        ]
        XCTAssertEqual(relationDict[.blocking], "blocks")
        XCTAssertEqual(relationDict[.blocked], "blocked by")
    }
}

// MARK: - Test Helper Extensions

extension APIError: @retroactive Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.badURL, .badURL), (.decoding, .decoding), (.missingToken, .missingToken), (.totpRequired, .totpRequired):
            return true
        case (.http(let code1), .http(let code2)):
            return code1 == code2
        case (.other(let msg1), .other(let msg2)):
            return msg1 == msg2
        default:
            return false
        }
    }
}
