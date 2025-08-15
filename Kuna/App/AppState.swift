// App/AppState.swift
import SwiftUI
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var api: VikunjaAPI?

    init() {
        // Check if we have stored credentials
        if let serverURLString = Keychain.readServerURL(),
           let token = Keychain.readToken() {
            Log.app.debug("Found stored token at startup (value not logged)")
            do {
                let apiURL = try Self.buildAPIURL(from: serverURLString)
                self.api = VikunjaAPI(
                    config: .init(baseURL: apiURL),
                    tokenProvider: { 
                        let t = Keychain.readToken()
                        // Do not log token values
                        return t
                    }
                )
                self.isAuthenticated = true
            } catch {
                // Invalid stored URL, clear credentials
                Log.app.error("Error building API URL from stored server URL; clearing credentials")
                Keychain.clearAll()
                self.api = nil
                self.isAuthenticated = false
            }
        } else {
            Log.app.debug("No stored credentials found")
            self.api = nil
            self.isAuthenticated = false
        }
    }
    
    private static func buildAPIURL(from serverURL: String) throws -> URL {
        // Clean up the URL - remove trailing slashes
        let cleanURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Ensure it has a scheme
        let urlWithScheme = cleanURL.hasPrefix("http://") || cleanURL.hasPrefix("https://") 
            ? cleanURL 
            : "https://\(cleanURL)"
        
        // Append /api/v1 to the base URL
        guard let apiURL = URL(string: "\(urlWithScheme)/api/v1") else {
            throw APIError.badURL
        }
        
        return apiURL
    }

    func login(serverURL: String, username: String, password: String) async throws {
        let apiURL = try Self.buildAPIURL(from: serverURL)
        
        // Create temporary API instance for login
        let tempAPI = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { nil }
        )
        
        let token = try await tempAPI.login(username: username, password: password)
        
        // Save credentials
        try Keychain.saveToken(token)
        try Keychain.saveServerURL(serverURL)
        
        // Create authenticated API instance
        self.api = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { Keychain.readToken() }
        )
        
        isAuthenticated = true
    }

    func usePersonalToken(serverURL: String, token: String) throws {
        let apiURL = try Self.buildAPIURL(from: serverURL)
        
        Log.app.debug("Saving API token (value not logged)")
        
        // Save credentials
        try Keychain.saveToken(token)
        try Keychain.saveServerURL(serverURL)
        
        // Verify token was saved
        if Keychain.readToken() != nil {
            Log.app.debug("Token saved and retrieved (value not logged)")
        } else {
            Log.app.error("Token was not saved properly")
        }
        
        // Create authenticated API instance
        self.api = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { 
                let t = Keychain.readToken()
                // Do not log token values
                return t
            }
        )
        
        isAuthenticated = true
    }

    func logout() {
        Keychain.clearAll()
        api = nil
        isAuthenticated = false
    }
}
