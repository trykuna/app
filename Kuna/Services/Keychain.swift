// Services/Keychain.swift
import Foundation
import Security

// Forward declaration - AuthenticationMethod is defined in AppState.swift
// This will work because both files are compiled together

enum Keychain {
    // App Group identifier - must match in both app and widget entitlements
    private static let appGroupIdentifier = "group.tech.systemsmystery.kuna"
    
    static func save(token: String, account: String = "vikunja-token") throws {
        let data = Data(token.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add app group for sharing with widget
        query[kSecAttrAccessGroup as String] = appGroupIdentifier
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func read(account: String = "vikunja-token") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: appGroupIdentifier
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func delete(account: String = "vikunja-token") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: appGroupIdentifier
        ]
        SecItemDelete(query as CFDictionary)
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
