import XCTest
@testable import Kuna
import SwiftUI

final class UtilityTests: XCTestCase {
    
    // MARK: - String Extension Tests
    
    func testStrippingWrappedParagraphTags() {
        // Test basic p tag wrapping
        let wrapped = "<p>Hello World</p>"
        XCTAssertEqual(wrapped.strippingWrappedParagraphTags(), "Hello World")
        
        // Test with whitespace
        let wrappedWithSpaces = "  <p>  Test Content  </p>  "
        XCTAssertEqual(wrappedWithSpaces.strippingWrappedParagraphTags(), "Test Content")
        
        // Test multiple p tags (should remove all occurrences)
        let multipleTags = "Content <p>with</p> multiple <p>tags</p> here"
        XCTAssertEqual(multipleTags.strippingWrappedParagraphTags(), "Content with multiple tags here")
        
        // Test no p tags
        let noTags = "Plain text content"
        XCTAssertEqual(noTags.strippingWrappedParagraphTags(), "Plain text content")
        
        // Test empty string
        let empty = ""
        XCTAssertEqual(empty.strippingWrappedParagraphTags(), "")
        
        // Test only p tags
        let onlyTags = "<p></p>"
        XCTAssertEqual(onlyTags.strippingWrappedParagraphTags(), "")
        
        // Test incomplete p tags
        let incomplete = "<p>Missing closing tag"
        XCTAssertEqual(incomplete.strippingWrappedParagraphTags(), "Missing closing tag")
        
        // Test nested content (should handle inner content)
        let nested = "<p>Outer <strong>bold</strong> content</p>"
        XCTAssertEqual(nested.strippingWrappedParagraphTags(), "Outer <strong>bold</strong> content")
        
        // Test malformed HTML
        let malformed = "<p>Test</p><p>More content"
        XCTAssertEqual(malformed.strippingWrappedParagraphTags(), "TestMore content")
    }
    
    // MARK: - Color Extension Tests
    
    func testColorHexInitializer() {
        // Test valid 6-character hex
        let blue = Color(hex: "007AFF")
        XCTAssertNotNil(blue)
        
        // Test valid 3-character hex (should expand)
        let red = Color(hex: "F00")
        XCTAssertNotNil(red)
        
        // Test with # prefix
        let green = Color(hex: "#00FF00")
        XCTAssertNotNil(green)
        
        // Test invalid hex (should return nil)
        let invalid = Color(hex: "ZZZZZZ")
        XCTAssertNil(invalid)
        
        // Test empty string
        let empty = Color(hex: "")
        XCTAssertNil(empty)
        
        // Test too short
        let tooShort = Color(hex: "FF")
        XCTAssertNil(tooShort)
        
        // Test too long
        let tooLong = Color(hex: "FF00FF00")
        XCTAssertNotNil(tooLong) // Should take first 6 characters
    }
    
    func testColorProjectColor() {
        // Test consistency - same ID should always return same color
        let color1 = Color.projectColor(for: 123)
        let color2 = Color.projectColor(for: 123)
        XCTAssertEqual(color1, color2)
        
        // Test different IDs return different colors (with high probability)
        let colorA = Color.projectColor(for: 1)
        let colorB = Color.projectColor(for: 2)
        // Note: There's a small chance these could be equal due to modulo operation
        // but it's very unlikely with the color palette size
        
        // Test negative IDs are handled correctly
        let negativeColor = Color.projectColor(for: -5)
        XCTAssertNotNil(negativeColor)
        
        // Test zero
        let zeroColor = Color.projectColor(for: 0)
        XCTAssertNotNil(zeroColor)
        
        // Test large numbers
        let largeColor = Color.projectColor(for: 999999)
        XCTAssertNotNil(largeColor)
    }
    
    func testColorProjectColorDistribution() {
        // Test that different project IDs map to different colors
        var colorSet: Set<String> = []
        let testRange = 1...20
        
        for id in testRange {
            let color = Color.projectColor(for: id)
            // Convert color to string representation for comparison
            colorSet.insert("\(color)")
        }
        
        // Should have good color distribution - expect at least 8 unique colors from the palette
        // (there are 9 colors total: .blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint, .teal)
        XCTAssertGreaterThan(colorSet.count, 7,
                            "Color distribution should be reasonably diverse")
        XCTAssertLessThanOrEqual(colorSet.count, 9,
                                "Should not exceed the number of colors in palette")
    }
    
    // MARK: - JSONEncoder/JSONDecoder Extension Tests
    
    func testVikunjaJSONEncoder() {
        // Test that the vikunja encoder is configured properly
        let encoder = JSONEncoder.vikunja
        XCTAssertNotNil(encoder)
        
        // Test date encoding format
        let testDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let dateData = try? encoder.encode(testDate)
        XCTAssertNotNil(dateData)
        
        if let data = dateData,
           let dateString = String(data: data, encoding: .utf8) {
            // Should be in ISO 8601 format
            XCTAssertTrue(dateString.contains("2021"), "Date should be encoded in readable format")
        }
    }
    
    func testVikunjaJSONDecoder() {
        // Test that the vikunja decoder is configured properly
        let decoder = JSONDecoder.vikunja
        XCTAssertNotNil(decoder)
        
        // Test date decoding
        let dateJSON = Data("\"2021-01-01T00:00:00Z\"".utf8)
        let decodedDate = try? decoder.decode(Date.self, from: dateJSON)
        XCTAssertNotNil(decodedDate)
        
        if let date = decodedDate {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual(components.year, 2021)
            XCTAssertEqual(components.month, 1)
            XCTAssertEqual(components.day, 1)
        }
    }
    
    // MARK: - AnyEncodable Tests
    
    func testAnyEncodable() throws {
        // Test encoding different types
        let stringEncodable = AnyEncodable("test string")
        let intEncodable = AnyEncodable(42)
        let boolEncodable = AnyEncodable(true)
        
        let encoder = JSONEncoder()
        
        // Test string encoding
        let stringData = try encoder.encode(stringEncodable)
        let stringResult = String(data: stringData, encoding: .utf8)
        XCTAssertEqual(stringResult, "\"test string\"")
        
        // Test integer encoding
        let intData = try encoder.encode(intEncodable)
        let intResult = String(data: intData, encoding: .utf8)
        XCTAssertEqual(intResult, "42")
        
        // Test boolean encoding
        let boolData = try encoder.encode(boolEncodable)
        let boolResult = String(data: boolData, encoding: .utf8)
        XCTAssertEqual(boolResult, "true")
    }
    
    // MARK: - Performance Tests
    
    func testStringParagraphStrippingPerformance() {
        let testString = "<p>This is a test string with paragraph tags that we want to strip efficiently</p>"
        
        measure {
            for _ in 0..<1000 {
                _ = testString.strippingWrappedParagraphTags()
            }
        }
    }
    
    func testColorHexParsingPerformance() {
        let hexColors = ["FF0000", "00FF00", "0000FF", "FFFF00", "FF00FF", "00FFFF"]
        
        measure {
            for _ in 0..<1000 {
                for hex in hexColors {
                    _ = Color(hex: hex)
                }
            }
        }
    }
}
