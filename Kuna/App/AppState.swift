// App/AppState.swift
import SwiftUI
import Foundation

enum AuthenticationMethod: String, CaseIterable {
    case usernamePassword = "Username & Password"
    case personalToken = "Personal API Token"

    var description: String {
        return self.rawValue
    }

    var systemImage: String {
        switch self {
        case .usernamePassword: return "person.circle"
        case .personalToken: return "key"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var api: VikunjaAPI?
    @Published var authenticationMethod: AuthenticationMethod?
    @Published var tokenExpirationDate: Date?
    @Published var deepLinkTaskId: Int?

    init() {
        // Initialize all properties first
        self.isAuthenticated = false
        self.api = nil
        self.authenticationMethod = nil
        self.tokenExpirationDate = nil

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
                    },
                    tokenRefreshHandler: { [weak self] newToken in
                        try await self?.refreshToken(newToken: newToken)
                    },
                    tokenRefreshFailureHandler: { [weak self] in
                        self?.handleTokenRefreshFailure()
                    }
                )
                self.isAuthenticated = true
                // Determine authentication method from stored data
                self.authenticationMethod = Keychain.readAuthMethod()
                // Decode token to get expiration date
                self.tokenExpirationDate = try? JWTDecoder.getExpirationDate(from: token)
            } catch {
                // Invalid stored URL, clear credentials
                Log.app.error("Error building API URL from stored server URL; clearing credentials")
                Keychain.clearAll()
                self.api = nil
                self.isAuthenticated = false
                self.authenticationMethod = nil
                self.tokenExpirationDate = nil
            }
        } else {
            Log.app.debug("No stored credentials found")
        }

        // Start memory monitoring in debug builds only
        #if DEBUG
        startMemoryMonitoring()
        #endif
    }

    static func buildAPIURL(from serverURL: String) throws -> URL {
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

        // Create temporary API instance for login (no token refresh needed)
        let tempAPI = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { nil }
        )

        let token = try await tempAPI.login(username: username, password: password)

        // Decode token to get expiration date
        let expirationDate = try? JWTDecoder.getExpirationDate(from: token)

        #if DEBUG
        if let expDate = expirationDate {
            Log.app.debug("Token expires at: \(expDate, privacy: .public)")
        } else {
            Log.app.debug("Could not decode token expiration")
        }
        #endif

        // Save credentials
        try Keychain.saveToken(token)
        try Keychain.saveServerURL(serverURL)
        try Keychain.saveAuthMethod(.usernamePassword)

        // Create authenticated API instance
        self.api = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { Keychain.readToken() },
            tokenRefreshHandler: { [weak self] newToken in
                try await self?.refreshToken(newToken: newToken)
            },
            tokenRefreshFailureHandler: { [weak self] in
                self?.handleTokenRefreshFailure()
            }
        )

        isAuthenticated = true
        authenticationMethod = .usernamePassword
        tokenExpirationDate = expirationDate
    }

    func loginWithTOTP(serverURL: String, username: String, password: String, totpCode: String) async throws {
        let apiURL = try Self.buildAPIURL(from: serverURL)

        // Create temporary API instance for login (no token refresh needed)
        let tempAPI = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { nil }
        )

        let token = try await tempAPI.loginWithTOTP(username: username, password: password, totpCode: totpCode)

        // Decode token to get expiration date
        let expirationDate = try? JWTDecoder.getExpirationDate(from: token)

        #if DEBUG
        if let expDate = expirationDate {
            Log.app.debug("TOTP Token expires at: \(expDate, privacy: .public)")
        } else {
            Log.app.debug("Could not decode TOTP token expiration")
        }
        #endif

        // Save credentials
        try Keychain.saveToken(token)
        try Keychain.saveServerURL(serverURL)
        try Keychain.saveAuthMethod(.usernamePassword)

        // Create authenticated API instance
        self.api = VikunjaAPI(
            config: .init(baseURL: apiURL),
            tokenProvider: { Keychain.readToken() },
            tokenRefreshHandler: { [weak self] newToken in
                try await self?.refreshToken(newToken: newToken)
            },
            tokenRefreshFailureHandler: { [weak self] in
                self?.handleTokenRefreshFailure()
            }
        )

        isAuthenticated = true
        authenticationMethod = .usernamePassword
        tokenExpirationDate = expirationDate
    }

    func usePersonalToken(serverURL: String, token: String) throws {
        let apiURL = try Self.buildAPIURL(from: serverURL)

        Log.app.debug("Saving API token (value not logged)")

        // Save credentials
        try Keychain.saveToken(token)
        try Keychain.saveServerURL(serverURL)
        try Keychain.saveAuthMethod(.personalToken)

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
            },
            tokenRefreshHandler: { [weak self] newToken in
                // Personal tokens don't refresh, but we include the handler for consistency
                try await self?.refreshToken(newToken: newToken)
            },
            tokenRefreshFailureHandler: { [weak self] in
                self?.handleTokenRefreshFailure()
            }
        )

        isAuthenticated = true
        authenticationMethod = .personalToken
        // Personal tokens don't have expiration in JWT format, so we don't decode them
        tokenExpirationDate = nil
    }

    func logout() {
        Keychain.clearAll()
        // Reset app preferences on sign out
        AppSettings.shared.resetToDefaults()
        api = nil
        isAuthenticated = false
        authenticationMethod = nil
        tokenExpirationDate = nil
    }

    // MARK: - Token Management
    var isTokenExpiringSoon: Bool {
        guard let expirationDate = tokenExpirationDate else { return false }
        let timeUntilExpiration = expirationDate.timeIntervalSinceNow
        return timeUntilExpiration > 0 && timeUntilExpiration < 86400 // Less than 24 hours
    }

    var isTokenExpired: Bool {
        guard let expirationDate = tokenExpirationDate else { return false }
        return Date() > expirationDate
    }

    var timeUntilTokenExpiration: TimeInterval? {
        guard let expirationDate = tokenExpirationDate else { return nil }
        let timeInterval = expirationDate.timeIntervalSinceNow
        return timeInterval > 0 ? timeInterval : nil
    }

    /// User management features are only available for username/password authentication
    var canManageUsers: Bool {
        return authenticationMethod == .usernamePassword
    }

    // MARK: - Token Refresh
    @MainActor
    func refreshToken(newToken: String) async throws {
        // Decode the new token to get expiration
        let expirationDate = try? JWTDecoder.getExpirationDate(from: newToken)

        // Update keychain with new token
        try Keychain.saveToken(newToken)

        // Update our state
        self.tokenExpirationDate = expirationDate

        #if DEBUG
        if let expDate = expirationDate {
            Log.app.debug("Token refreshed, new expiration: \(expDate, privacy: .public)")
        } else {
            Log.app.debug("Token refreshed but could not decode expiration")
        }
        #endif
    }

    // Handle token refresh failures by logging out the user
    func handleTokenRefreshFailure() {
        #if DEBUG
        Log.app.debug("Token refresh failed, logging out user")
        #endif

        logout()
    }
    
    // MARK: - Memory Management
    private var memoryMonitorTimer: Timer?
    private var memoryWarningCount = 0
    private var lastCleanupTime: Date = Date.distantPast
    private let criticalMemoryThreshold: UInt64 = 150 * 1024 * 1024 // 150MB - reasonable threshold
    
    private func startMemoryMonitoring() {
        #if DEBUG
        // Monitor memory usage every 30 seconds for debugging only
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryUsage()
            }
        }
        #endif
    }
    
    private func checkMemoryUsage() {
        let resident = getMemoryUsage()
        
        // Only log memory usage periodically for debugging, don't trigger aggressive cleanup
        Log.app.debug("Memory - Resident: \(resident / 1024 / 1024)MB")
        
        // Track peak memory usage for debugging
        let currentPeak = UserDefaults.standard.object(forKey: "peakMemoryUsage") as? UInt64 ?? 0
        if resident > currentPeak {
            UserDefaults.standard.set(resident, forKey: "peakMemoryUsage")
            Log.app.debug("New peak memory usage: \(resident / 1024 / 1024)MB")
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        let (resident, _, _) = getDetailedMemoryUsage()
        return resident // Only use resident memory - it's the most reliable
    }
    
    private func getDetailedMemoryUsage() -> (resident: UInt64, dirty: UInt64, compressed: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Just use the basic resident size - VM stats are giving wrong values
            return (
                resident: info.resident_size,
                dirty: 0, // Don't calculate dirty pages - it's unreliable
                compressed: 0 // Don't calculate compressed - it's unreliable
            )
        }
        
        return (resident: 0, dirty: 0, compressed: 0)
    }
    
    private func performEmergencyMemoryCleanup() {
        Log.app.warning("AppState: Performing emergency memory cleanup")
        
        // Clear our own cached data
        deepLinkTaskId = nil
        
        // Trigger cleanup in all services
        CommentCountManager.shared?.clearCache()
        WidgetCacheWriter.performMemoryCleanup()
        BackgroundTaskChangeDetector.shared.performMemoryCleanup()
        
        // More aggressive cleanup
        URLCache.shared.removeAllCachedResponses()
        
        // Clear UserDefaults cache that might be holding data
        UserDefaults.standard.synchronize()
        
        // Multiple rounds of garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                // Create and release memory to trigger GC
                let _ = Array(repeating: Data(count: 1024), count: 1000)
            }
        }
        
        Log.app.warning("AppState: Emergency cleanup completed")
    }

    // Clean up memory on memory warnings
    func handleMemoryWarning() {
        self.memoryWarningCount += 1
        Log.app.warning("AppState: Handling memory warning #\(self.memoryWarningCount)")
        
        // Clear any cached data we might have
        self.deepLinkTaskId = nil
        
        // If we've had multiple memory warnings, be more aggressive
        if self.memoryWarningCount > 2 {
            self.performEmergencyMemoryCleanup()
        }
    }
    
    deinit {
        memoryMonitorTimer?.invalidate()
    }
}
