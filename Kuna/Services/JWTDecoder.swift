// Services/JWTDecoder.swift
import Foundation

struct JWTPayload: Codable {
    let exp: TimeInterval
    let iat: TimeInterval?
    let sub: String?
    let iss: String?
    
    var expirationDate: Date {
        return Date(timeIntervalSince1970: exp)
    }
    
    var issuedAtDate: Date? {
        guard let iat = iat else { return nil }
        return Date(timeIntervalSince1970: iat)
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
    
    var timeUntilExpiration: TimeInterval {
        return expirationDate.timeIntervalSinceNow
    }
}

enum JWTError: Error, LocalizedError {
    case invalidFormat
    case invalidBase64
    case decodingFailed
    case missingExpiration
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid JWT format"
        case .invalidBase64:
            return "Invalid Base64 encoding"
        case .decodingFailed:
            return "Failed to decode JWT payload"
        case .missingExpiration:
            return "JWT missing expiration time"
        }
    }
}

struct JWTDecoder {
    static func decode(_ token: String) throws -> JWTPayload {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw JWTError.invalidFormat
        }
        
        let payloadPart = parts[1]
        
        // Add padding if needed for Base64 decoding
        let paddedPayload = addBase64Padding(payloadPart)
        
        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            throw JWTError.invalidBase64
        }
        
        do {
            let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
            return payload
        } catch {
            throw JWTError.decodingFailed
        }
    }
    
    static func getExpirationDate(from token: String) throws -> Date {
        let payload = try decode(token)
        return payload.expirationDate
    }
    
    static func isTokenExpired(_ token: String) -> Bool {
        do {
            let payload = try decode(token)
            return payload.isExpired
        } catch {
            // If we can't decode the token, assume it's invalid/expired
            return true
        }
    }
    
    static func timeUntilExpiration(for token: String) -> TimeInterval? {
        do {
            let payload = try decode(token)
            return payload.timeUntilExpiration
        } catch {
            return nil
        }
    }
    
    private static func addBase64Padding(_ string: String) -> String {
        let remainder = string.count % 4
        if remainder > 0 {
            return string + String(repeating: "=", count: 4 - remainder)
        }
        return string
    }
}

// Extension to format time intervals nicely
extension TimeInterval {
    var formattedDuration: String {
        let days = Int(self) / 86400
        let hours = Int(self) % 86400 / 3600
        let minutes = Int(self) % 3600 / 60
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "Less than a minute"
        }
    }
}
