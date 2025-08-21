// Services/Keychain.swift
import Foundation
import Security

// Forward declaration - AuthenticationMethod is defined in AppState.swift
// This will work because both files are compiled together

enum Keychain {
    // App Group identifier - must match in both app and widget entitlements
    private static let appGroupIdentifier = "group.tech.systemsmystery.kuna"

    // In-memory cache to avoid repeated Keychain lookups per process
    private static var cache: [String: String] = [:]
    private static let cacheQueue = DispatchQueue(label: "tech.systemsmystery.kuna.keychain-cache")

    enum KeychainError: Error, CustomStringConvertible {
        case itemNotFound
        case osStatus(OSStatus, String)

        var description: String {
            switch self {
            case .itemNotFound:
                return "Item not found"
            case .osStatus(let code, let message):
                return "OSStatus(\(code)): \(message)"
            }
        }
    }

    @inline(__always)
    private static func osStatusMessage(_ status: OSStatus) -> String {
        if let s = SecCopyErrorMessageString(status, nil) as String? {
            return s
        }
        return "OSStatus(\(status))"
    }

    static func save(token: String, account: String = "vikunja-token") throws {
        let data = Data(token.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Restrict to this device and allow access after first unlock to support background tasks/widgets
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Add app group for sharing with widget
        query[kSecAttrAccessGroup as String] = appGroupIdentifier

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            let message = osStatusMessage(status)
            Log.app.error("Keychain save failed for account: \(account, privacy: .public) — status: \(status, privacy: .public) message: \(message, privacy: .public)")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        // Update in-memory cache on success
        cacheQueue.sync { cache[account] = token }
    }

    /// Read a string from Keychain with explicit error reporting
    static func readResult(account: String = "vikunja-token") -> Result<String?, KeychainError> {
        // Serve from cache if available (thread-safe)
        if let cached = cacheQueue.sync(execute: { cache[account] }) {
            return .success(cached)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: appGroupIdentifier
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            if let data = out as? Data {
                let value = String(decoding: data, as: UTF8.self)
                cacheQueue.sync { cache[account] = value }
                return .success(value)
            } else {
                Log.app.error("Keychain read returned success but no data for account: \(account, privacy: .public)")
                return .success(nil)
            }
        case errSecItemNotFound:
            return .success(nil)
        default:
            let message = osStatusMessage(status)
            Log.app.error("Keychain read failed for account: \(account, privacy: .public) — status: \(status, privacy: .public) message: \(message, privacy: .public)")
            return .failure(.osStatus(status, message))
        }
    }

    static func read(account: String = "vikunja-token") -> String? {
        switch readResult(account: account) {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    static func delete(account: String = "vikunja-token") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: appGroupIdentifier
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            let message = osStatusMessage(status)
            Log.app.error("Keychain delete failed for account: \(account, privacy: .public) — status: \(status, privacy: .public) message: \(message, privacy: .public)")
        }
//        cacheQueue.sync { cache.removeValue(forKey: account) }
    }
    
    // Server URL storage
    static func saveServerURL(_ url: String) throws {
        try save(token: url, account: "vikunja-server")
    }
    
    static func readServerURL() -> String? {
        return read(account: "vikunja-server")
    }
    
    static func deleteServerURL() {
        delete(account: "vikunja-server")
    }
    
    // Convenience methods for token
    static func saveToken(_ token: String) throws {
        try save(token: token, account: "vikunja-token")
    }
    
    static func readToken() -> String? {
        return read(account: "vikunja-token")
    }
    
    static func deleteToken() {
        delete(account: "vikunja-token")
    }
    
    // Authentication method storage
    static func saveAuthMethod(_ method: AuthenticationMethod) throws {
        try save(token: method.rawValue, account: "vikunja-auth-method")
    }

    static func readAuthMethod() -> AuthenticationMethod? {
        guard let methodString = read(account: "vikunja-auth-method") else { return nil }
        return AuthenticationMethod(rawValue: methodString)
    }

    static func deleteAuthMethod() {
        delete(account: "vikunja-auth-method")
    }

    // Clear all
    static func clearAll() {
        deleteToken()
        deleteServerURL()
        deleteAuthMethod()
    }
}
