// Services/VikunjaAPI.swift
import Foundation

struct VikunjaConfig {
    var baseURL: URL   // e.g. https://vikunja.yourdomain/api/v1
}

struct Endpoint {
    let method: String
    let pathComponents: [String]
    let queryItems: [URLQueryItem]

    init(method: String, pathComponents: [String], queryItems: [URLQueryItem] = []) {
        self.method = method
        self.pathComponents = pathComponents
        self.queryItems = queryItems
    }
}

enum APIError: Error, LocalizedError {
    case badURL
    case http(Int)
    case decoding
    case missingToken
    case totpRequired
    case invalidCredentials
    case invalidTOTP
    case other(String)

    var errorDescription: String? {
        switch self {
        case .badURL:                return "Bad URL"
        case .http(let code):        return "HTTP \(code)"
        case .decoding:              return "Decoding failed"
        case .missingToken:          return "No auth token"
        case .totpRequired:          return "TOTP code required"
        case .invalidCredentials:    return "Wrong username or password"
        case .invalidTOTP:           return "Invalid TOTP passcode"
        case .other(let s):          return s
        }
    }
}

final class VikunjaAPI {

    // MARK: - URL building

    private func url(for endpoint: Endpoint) throws -> URL {
        var url = config.baseURL
        for c in endpoint.pathComponents { url.appendPathComponent(c) }
        if !endpoint.queryItems.isEmpty {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comp?.queryItems = endpoint.queryItems
            guard let u = comp?.url else { throw APIError.badURL }
            url = u
        }
        return url
    }

    // MARK: - Request context (optional, kept for future use)

    private struct RequestContext {
        let isLogin: Bool
        let sentTOTP: Bool
    }

    private enum AuthPrecondition {
        case totpRequired
        case invalidTOTP
        case invalidCredentials
        case unknown
    }

    private func classifyAuthPrecondition(message: String, context: RequestContext? = nil) -> AuthPrecondition {
        let m = message.lowercased()

        // Invalid username/password (code 1011)
        if m.contains("wrong username or password") ||
           m.contains("invalid username") || m.contains("invalid password") ||
           (m.contains("authentication") && m.contains("failed")) {
            return .invalidCredentials
        }

        // For "Invalid totp passcode" (code 1017), check if TOTP was actually sent
        // If no TOTP was sent, this means TOTP is required
        // If TOTP was sent, this means the TOTP was wrong
        if m.contains("invalid totp") || m.contains("invalid totp passcode") ||
           m.contains("totp passcode invalid") || m.contains("wrong totp") {
            // If we have context about whether TOTP was sent, use it
            if let sentTOTP = context?.sentTOTP {
                return sentTOTP ? .invalidTOTP : .totpRequired
            }
            // Without context, we assume it means TOTP is required (safer default for UI)
            return .totpRequired
        }

        // TOTP explicitly required / missing
        if (m.contains("totp") && (m.contains("required") || m.contains("missing"))) ||
           m.contains("two-factor") || m.contains("2fa") || m.contains("precondition failed: totp") {
            return .totpRequired
        }

        return .unknown
    }

    // MARK: - Core request helpers

    // Backward-compatible string-path request kept for now
    @discardableResult
    private func request(_ path: String,
                         method: String = "GET",
                         body: (some Encodable)? = Optional<String>.none) async throws -> Data {
        return try await request(Endpoint(method: method, pathComponents: path.split(separator: "/").map(String.init)),
                                 body: body)
    }

    // New Endpoint-based request
    private func request(_ endpoint: Endpoint, body: (some Encodable)? = Optional<String>.none) async throws -> Data {
        let (data, _) = try await requestWithResponse(endpoint, body: body, context: nil)
        return data
    }

    // Variant that returns both data and HTTPURLResponse (needed to read pagination headers)
    private func requestWithResponse(_ endpoint: Endpoint,
                                     body: (some Encodable)? = Optional<String>.none,
                                     context: RequestContext? = nil) async throws -> (Data, HTTPURLResponse) {
        let url = try url(for: endpoint)
        Log.network.debug("Request: \(endpoint.method, privacy: .public) \(url.absoluteString, privacy: .public)")

        // Skip token validation for auth endpoints
        let isAuthEndpoint = endpoint.pathComponents.contains("login") ||
                             endpoint.pathComponents.contains("token") ||
                             endpoint.pathComponents.joined(separator: "/") == "user/token"

        if !isAuthEndpoint && tokenRefreshHandler != nil {
            try await ensureValidToken()
        }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = tokenProvider() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            Log.network.debug("Authorization header set for endpoint \(endpoint.pathComponents.joined(separator: "/"), privacy: .public)") // swiftlint:disable:this line_length
            #endif
        } else if !isAuthEndpoint {
            Log.network.error("No token available for request to \(url.absoluteString, privacy: .public)")
        }
        if let enc = body {
            req.httpBody = try JSONEncoder.vikunja.encode(AnyEncodable(enc))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let isGet = endpoint.method.uppercased() == "GET"
        var lastError: Error?

        for attempt in 1...3 {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw APIError.other("No HTTP response") }
                Log.network.debug("Response: status=\(http.statusCode, privacy: .public) url=\(url.absoluteString, privacy: .public)") // swiftlint:disable:this line_length

                if (200..<300).contains(http.statusCode) {
                    return (data, http)
                }

                if isGet && (
                        http.statusCode == 500 || http.statusCode == 502 || http.statusCode == 503 || http.statusCode == 504)
                    && attempt < 3 {
                    let delay = UInt64(pow(2.0, Double(attempt - 1)) * 0.3 * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }

                if LogConfig.verboseNetwork {
                    let serverMessage = extractErrorMessage(from: data) ?? ""
                    if serverMessage.isEmpty {
                        Log.network.debug("HTTP error status=\(http.statusCode, privacy: .public)")
                    } else {
                        Log.network.debug("HTTP error status=\(http.statusCode, privacy: .public) message=\(serverMessage, privacy: .public)") // swiftlint:disable:this line_length
                    }
                }

                // --- Auth-specific handling ---

                if http.statusCode == 412 {
                    // Log the raw response for debugging 412 errors
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response as UTF-8"
                    Log.network.error("HTTP 412 Precondition Failed - Raw response: \(rawResponse, privacy: .public)")
                    
                    let serverMessage = extractErrorMessage(from: data) ?? ""
                    Log.network.error("HTTP 412 Precondition Failed - Extracted message: \(serverMessage.isEmpty ? "<empty>" : serverMessage, privacy: .public)") // swiftlint:disable:this line_length
                    
                    #if DEBUG
                    Log.network.debug("HTTP 412 body(raw): \(rawResponse, privacy: .public)")
                    #endif

                    let isLogin = endpoint.pathComponents.contains("login")
                    if isLogin {
                        // STRICT rule for /login:
                        // - If message explicitly says creds are wrong -> invalidCredentials
                        // - If message says "Invalid totp passcode" WITH NO TOTP sent -> totpRequired
                        // - If message says "Invalid totp passcode" WITH TOTP sent -> invalidTOTP
                        // - Otherwise -> check context and decide
                        let msg = serverMessage.lowercased()
                        
                        Log.network.info("HTTP 412 on /login endpoint - Message: '\(serverMessage, privacy: .public)'")

                        // Check if credentials are wrong first (code 1011)
                        if msg.contains("wrong username or password") ||
                            msg.contains("invalid username") || msg.contains("invalid password") ||
                            (msg.contains("authentication") && msg.contains("failed")) {
                                Log.network.error("412(/login) -> INVALID_CREDENTIALS - matched: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                                throw APIError.invalidCredentials
                        }

                        // For "Invalid totp passcode" (code 1017), we need to check context
                        if msg.contains("invalid totp") || msg.contains("invalid totp passcode") ||
                            msg.contains("totp passcode invalid") || msg.contains("wrong totp") {
                                // Check if we actually sent a TOTP code in this request
                                let sentTOTP = context?.sentTOTP ?? false
                                
                                if sentTOTP {
                                    // We sent a TOTP but it was wrong
                                    Log.network.error("412(/login) -> INVALID_TOTP - TOTP was sent but incorrect: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                                    throw APIError.invalidTOTP
                                } else {
                                    // We didn't send a TOTP, so this means TOTP is required
                                    Log.network.info("412(/login) -> TOTP_REQUIRED - No TOTP sent, server requires it: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                                    throw APIError.totpRequired
                                }
                        }

                        Log.network.info("412(/login) -> TOTP_REQUIRED (strict fallback) - message was: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                        throw APIError.totpRequired
                    }

                    // Non-login endpoints: classify normally
                    let meaning = classifyAuthPrecondition(message: serverMessage, context: context)
                    Log.network.info("HTTP 412 on non-login endpoint - Classification: \(String(describing: meaning), privacy: .public), Message: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                    
                    switch meaning {
                    case .invalidCredentials:
                        Log.network.error("412 -> INVALID_CREDENTIALS (non-login) - message: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                        throw APIError.invalidCredentials
                    case .invalidTOTP:
                        Log.network.error("412 -> INVALID_TOTP (non-login) - message: '\(serverMessage, privacy: .public)'")
                        throw APIError.invalidTOTP
                    case .totpRequired:
                        Log.network.info("412 -> TOTP_REQUIRED (non-login) - message: '\(serverMessage, privacy: .public)'")
                        throw APIError.totpRequired
                    case .unknown:
                        Log.network.warning("412 -> HTTP(412) (unknown, non-login) - message: '\(serverMessage, privacy: .public)'") // swiftlint:disable:this line_length
                        if !serverMessage.isEmpty { throw APIError.other(serverMessage) }
                        throw APIError.http(412)
                    }
                }

                // Optional: 401 as invalid credentials on some setups
                if http.statusCode == 401 {
                    let serverMessage = extractErrorMessage(from: data) ?? ""
                    if serverMessage.isEmpty {
                        Log.network.debug("401 -> INVALID_CREDENTIALS")
                        throw APIError.invalidCredentials
                    } else {
                        Log.network.debug("401 -> OTHER(\(serverMessage))")
                        throw APIError.other(serverMessage)
                    }
                }

                // Try to extract server error message
                let message = extractErrorMessage(from: data)
                if let message, !message.isEmpty {
                    throw APIError.other(message)
                } else {
                    throw APIError.http(http.statusCode)
                }
            } catch {
                lastError = error
                if isGet && attempt < 3 {
                    let delay = UInt64(pow(2.0, Double(attempt - 1)) * 0.3 * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }
        throw lastError ?? APIError.other("Unknown error")
    }

    // MARK: - Pagination helpers

    private struct PaginationInfo {
        let totalPages: Int?
        let currentPage: Int?
        let perPage: Int?
        let resultCount: Int?
        let totalCount: Int?
    }

    private func paginationInfo(from http: HTTPURLResponse) -> PaginationInfo {
        func headerInt(_ name: String) -> Int? {
            http.value(forHTTPHeaderField: name).flatMap { Int($0) }
        }
        func headerIntMulti(_ names: [String]) -> Int? {
            for n in names {
                if let v = headerInt(n) { return v }
            }
            return nil
        }
        // Vikunja docs use X-Pagination-* headers; some proxies/versions use alternatives
        let totalPages = headerIntMulti(["X-Pagination-Total-Pages", "X-Total-Pages"])
        let currentPage = headerIntMulti(["X-Pagination-Page", "X-Page"])
        let perPage = headerIntMulti(["X-Pagination-Per-Page", "X-Per-Page"])
        let resultCount = headerIntMulti(["X-Pagination-Result-Count", "X-Result-Count"])
        // Common total count headers used across setups
        var totalCount = headerIntMulti([
            "X-Pagination-Total-Count",
            "X-Total-Count",
            "X-Total",
            "X-Total-Items",
            "Total-Count"
        ])
        // Derive totalCount if missing but totalPages & perPage are known
        if totalCount == nil, let tp = totalPages, let pp = perPage {
            totalCount = tp * pp
        }
        return PaginationInfo(
            totalPages: totalPages, currentPage: currentPage, perPage: perPage, resultCount: resultCount, totalCount: totalCount)
    }

    // MARK: - Error payload extraction

    // Try to extract a human-friendly error message from Vikunja error payloads
    private func extractErrorMessage(from data: Data) -> String? {
        // Common shape: {"message":"..."}
        struct MsgOnly: Decodable { let message: String? }
        if let r = try? JSONDecoder.vikunja.decode(MsgOnly.self, from: data), let m = r.message, !m.isEmpty { return m }
        // Some APIs: {"error": {"message": "..."}}
        struct ErrWrap: Decodable { struct Err: Decodable { let message: String? }; let error: Err? }
        if let r = try? JSONDecoder.vikunja.decode(ErrWrap.self, from: data), let m = r.error?.message, !m.isEmpty { return m }
        // Fallback: {"error":"..."} or {"detail":"..."}
        struct Simple: Decodable { let error: String?; let detail: String? }
        if let r = try? JSONDecoder.vikunja.decode(Simple.self, from: data) {
            if let m = r.error, !m.isEmpty { return m }
            if let m = r.detail, !m.isEmpty { return m }
        }
        return nil
    }

    // MARK: - Deps

    private let config: VikunjaConfig
    /// Injected so this layer never touches Keychain directly.
    private let tokenProvider: () -> String?
    private let session: URLSession
    /// Handler to refresh token when it expires
    private let tokenRefreshHandler: ((String) async throws -> Void)?
    /// Handler for when token refresh fails
    private let tokenRefreshFailureHandler: (() async -> Void)?

    init(config: VikunjaConfig,
         tokenProvider: @escaping () -> String?,
         tokenRefreshHandler: ((String) async throws -> Void)? = nil,
         tokenRefreshFailureHandler: (() async -> Void)? = nil,
         session: URLSession? = nil) {
        self.config = config
        self.tokenProvider = tokenProvider
        self.tokenRefreshHandler = tokenRefreshHandler
        self.tokenRefreshFailureHandler = tokenRefreshFailureHandler

        // Use memory-optimized session configuration for better memory management
        if let customSession = session {
            self.session = customSession
        } else {
            let config = URLSessionConfiguration.default
            config.httpMaximumConnectionsPerHost = 4 // Limit concurrent connections
            config.timeoutIntervalForRequest = 30 // Shorter timeout
            config.timeoutIntervalForResource = 60
            config.urlCache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 0, diskPath: nil)
            config.requestCachePolicy = .reloadIgnoringLocalCacheData // Don't cache requests
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Token Management

    func refreshToken() async throws -> String {
        // Use the current token to get a new one
        let data = try await request("user/token", method: "POST")

        #if DEBUG
        Log.network.debug("Token refresh response bytes: \(data.count, privacy: .public)")
        #endif

        let auth = try JSONDecoder.vikunja.decode(AuthResponse.self, from: data)
        return auth.token
    }

    private func ensureValidToken() async throws {
        guard let currentToken = tokenProvider() else {
            throw APIError.missingToken
        }

        // Check if token is expired or expiring soon (within 5 minutes)
        if let timeUntilExpiration = JWTDecoder.timeUntilExpiration(for: currentToken),
           timeUntilExpiration < 300 { // 5 minutes

            #if DEBUG
            Log.network.debug("Token expires in \(timeUntilExpiration, privacy: .public) seconds, refreshing...")
            #endif

            // Try to refresh the token
            do {
                let newToken = try await refreshToken()

                // Notify the handler (AppState) about the new token
                try await tokenRefreshHandler?(newToken)

                #if DEBUG
                Log.network.debug("Token refreshed successfully")
                #endif
            } catch {
                #if DEBUG
                Log.network.error("Token refresh failed: \(String(describing: error), privacy: .public)")
                #endif
                await tokenRefreshFailureHandler?()
                throw error
            }
        } else if JWTDecoder.isTokenExpired(currentToken) {
            #if DEBUG
            Log.network.debug("Token is expired, attempting refresh...")
            #endif

            // Token is expired, try to refresh
            do {
                let newToken = try await refreshToken()
                try await tokenRefreshHandler?(newToken)

                #if DEBUG
                Log.network.debug("Expired token refreshed successfully")
                #endif
            } catch {
                #if DEBUG
                Log.network.error("Failed to refresh expired token: \(String(describing: error), privacy: .public)")
                #endif
                await tokenRefreshFailureHandler?()
                throw error
            }
        }
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> String {
        struct LoginBody: Encodable {
            let username: String
            let password: String
            let long_token: Bool = true
        }
        let ep = Endpoint(method: "POST", pathComponents: ["login"])
        let (data, _) = try await requestWithResponse(
            ep,
            body: LoginBody(username: username, password: password),
            context: RequestContext(isLogin: true, sentTOTP: false)
        )

        #if DEBUG
        Log.network.debug("Login response bytes: \(data.count, privacy: .public)")
        #endif

        let auth = try JSONDecoder.vikunja.decode(AuthResponse.self, from: data)
        return auth.token
    }

    func loginWithTOTP(username: String, password: String, totpCode: String) async throws -> String {
        struct LoginBodyWithTOTP: Encodable {
            let username: String
            let password: String
            let totp_passcode: String
            let long_token: Bool = true
        }
        let ep = Endpoint(method: "POST", pathComponents: ["login"])
        let (data, _) = try await requestWithResponse(
            ep,
            body: LoginBodyWithTOTP(username: username, password: password, totp_passcode: totpCode),
            context: RequestContext(isLogin: true, sentTOTP: true)
        )

        #if DEBUG
        Log.network.debug("Login with TOTP response bytes: \(data.count, privacy: .public)")
        #endif

        let auth = try JSONDecoder.vikunja.decode(AuthResponse.self, from: data)
        return auth.token
    }

    // MARK: - Projects

    func fetchProjects() async throws -> [Project] {
        let t0 = Date()
        var outcome = "success"
        var bytes = 0

        defer {
            let ms = Date().timeIntervalSince(t0) * 1000
            Task { @MainActor in
                Analytics.track(
                    "Projects.Fetch",
                    parameters: [
                        "duration_ms": String(Int(ms.rounded())),
                        "outcome": outcome,
                        "bytes": String(bytes)
                    ],
                    floatValue: ms
                )
            }
        }

        do {
            let data = try await request(Endpoint(method: "GET", pathComponents: ["projects"]))
            bytes = data.count

            #if DEBUG
            Log.network.debug("Projects response bytes: \(bytes, privacy: .public)")
            #endif

            return try JSONDecoder.vikunja.decode([Project].self, from: data)
        } catch let error as DecodingError {
            outcome = "decode_error"
            throw error
        } catch {
            outcome = "network_error"
            throw error
        }
    }

    func createProject(title: String, description: String? = nil) async throws -> Project {
        struct NewProject: Encodable {
            let title: String
            let description: String?
        }
        let newProject = NewProject(title: title, description: description)

        #if DEBUG
        Log.network.debug("Creating project body size bytes: \((try? JSONEncoder.vikunja.encode(newProject).count) ?? 0, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        let data = try await request("projects", method: "PUT", body: newProject)
        #if DEBUG
        Log.network.debug("Create project response bytes: \(data.count, privacy: .public)")
        #endif
        return try JSONDecoder.vikunja.decode(Project.self, from: data)
    }

    // MARK: - Tasks

    struct TasksResponse {
        let tasks: [VikunjaTask]
        let hasMore: Bool
        let currentPage: Int
        let totalPages: Int?
        let totalCount: Int?
    }

    // Paginated task fetching with optional query items
    func fetchTasks(
        projectId: Int, page: Int = 1, perPage: Int = 50, queryItems: [URLQueryItem] = []) async throws -> TasksResponse {
        var allQueryItems = queryItems
        allQueryItems.append(URLQueryItem(name: "page", value: String(page)))
        allQueryItems.append(URLQueryItem(name: "per_page", value: String(perPage)))

        let ep = Endpoint(method: "GET", pathComponents: ["projects", String(projectId), "tasks"], queryItems: allQueryItems)
        let (data, http) = try await requestWithResponse(ep, body: Optional<String>.none, context: nil)

        #if DEBUG
        Log.network.debug("Tasks(response) bytes: \(data.count, privacy: .public)")
        Log.network.debug("Fetching tasks for project \(projectId, privacy: .public), page \(page, privacy: .public), per_page \(perPage, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        // First try to decode as array (legacy, some endpoints still return a raw array)
        if let tasks = try? JSONDecoder.vikunja.decode([VikunjaTask].self, from: data) {
            #if DEBUG
            Log.network.debug("Decoded \(tasks.count, privacy: .public) tasks (raw array response)")
            #endif
            // Prefer pagination headers if present
            let p = paginationInfo(from: http)
            let totalPages = p.totalPages
            let hasMore = totalPages.map { page < $0 } ?? (tasks.count == perPage)
            return TasksResponse(
                tasks: tasks,
                hasMore: hasMore,
                currentPage: p.currentPage ?? page,
                totalPages: totalPages,
                totalCount: p.totalCount)
        }

        // Try paginated response body shape as a fallback
        struct PaginatedTasksBody: Decodable {
            let items: [VikunjaTask]?
            let results: [VikunjaTask]?
            let data: [VikunjaTask]?
            let totalPages: Int?
            let page: Int?

            var tasks: [VikunjaTask] { items ?? results ?? data ?? [] }
        }

        do {
            let body = try JSONDecoder.vikunja.decode(PaginatedTasksBody.self, from: data)
            let p = paginationInfo(from: http)
            let totalPages = body.totalPages ?? p.totalPages
            let current = body.page ?? p.currentPage ?? page
            let hasMore = totalPages.map { current < $0 } ?? 
                        (body.tasks.count == perPage)
            return TasksResponse(
                tasks: body.tasks,
                hasMore: hasMore,
                currentPage: current,
                totalPages: totalPages,
                totalCount: p.totalCount)
        } catch {
            #if DEBUG
            Log.network.error("Failed to decode tasks response: \(String(describing: error), privacy: .public)")
            if let s = String(data: data, encoding: .utf8) {
                Log.network.debug("Tasks response body: \(s, privacy: .public)")
            }
            #endif
            throw APIError.decoding
        }
    }

    // Convenience method for backward compatibility
    func fetchTasks(projectId: Int, queryItems: [URLQueryItem] = []) async throws -> [VikunjaTask] {
        let response = try await fetchTasks(projectId: projectId, page: 1, perPage: 50, queryItems: queryItems)
        return response.tasks
    }

    // Legacy method for backward compatibility
    func fetchTasks(projectId: Int) async throws -> [VikunjaTask] {
        return try await fetchTasks(projectId: projectId, queryItems: [])
    }

    func createTask(projectId: Int, title: String, description: String?) async throws -> VikunjaTask {
        struct NewTask: Encodable {
            let title: String
            let description: String?
        }
        let newTask = NewTask(title: title, description: description)

        #if DEBUG
        Log.network.debug("Creating task body size bytes: \((try? JSONEncoder.vikunja.encode(newTask).count) ?? 0, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        // PUT to /projects/{id}/tasks endpoint as per Vikunja API docs
        let data = try await request("projects/\(projectId)/tasks", method: "PUT", body: newTask)

        #if DEBUG
        Log.network.debug("Task creation response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)
    }

    func setTaskDone(task: VikunjaTask, done: Bool) async throws -> VikunjaTask {
        var updated = task
        updated.done = done

        #if DEBUG
        Log.network.debug("Updating task body size bytes: \((try? JSONEncoder.vikunja.encode(updated).count) ?? 0, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        // Use POST for updating tasks in Vikunja API
        let data = try await request("tasks/\(task.id)", method: "POST", body: updated)

        #if DEBUG
        Log.network.debug("Task update response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)
    }

    func updateTask(_ task: VikunjaTask) async throws -> VikunjaTask {
        // Debug: print what we're sending
        if let jsonData = try? JSONEncoder.vikunja.encode(task),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            Log.network.debug("Updating task with body: \(jsonString, privacy: .public)")
        }

        // Use POST for updating tasks in Vikunja API
        let data = try await request("tasks/\(task.id)", method: "POST", body: task)

        #if DEBUG
        Log.network.debug("Task update response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)
    }

    func getTask(taskId: Int) async throws -> VikunjaTask {
        let data = try await request("tasks/\(taskId)")

        #if DEBUG
        Log.network.debug("Get task response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)
    }

    // MARK: - Labels

    func fetchLabels() async throws -> [Label] {
        let data = try await request("labels")

        #if DEBUG
        Log.network.debug("Labels response bytes: \(data.count, privacy: .public)")
        #endif

        // Some servers may return 204 No Content (empty body) when there are no labels
        if data.isEmpty { return [] }
        // Some setups erroneously return literal "null" or "{}" for empty; treat as empty list
        if let s = String(data: data, encoding: .utf8) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t == "null" || t == "{}" { return [] }
        }

        // Primary: array of labels
        if let labels = try? JSONDecoder.vikunja.decode([Label].self, from: data) {
            return labels
        }

        // Fallback: object-wrapped lists
        struct LabelListWrap: Decodable {
            let labels: [Label]?
            let items: [Label]?
            let results: [Label]?
            let data: [Label]?
            var all: [Label] { labels ?? items ?? results ?? data ?? [] }
        }
        if let wrapped = try? JSONDecoder.vikunja.decode(LabelListWrap.self, from: data) {
            return wrapped.all
        }

        #if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            Log.network.debug("fetchLabels: unexpected response shape ->\n\(raw, privacy: .public)")
        }
        #endif

        throw APIError.decoding
    }

    func addLabelToTask(taskId: Int, labelId: Int) async throws -> VikunjaTask {
        struct LabelAssignment: Encodable { let label_id: Int }
        _ = try await request("tasks/\(taskId)/labels", method: "PUT",
                                body: LabelAssignment(label_id: labelId))

        // The API just returns a confirmation, not the updated task
        // So we need to fetch the updated task separately
        return try await getTask(taskId: taskId)
    }

    func removeLabelFromTask(taskId: Int, labelId: Int) async throws -> VikunjaTask {
        let data = try await request("tasks/\(taskId)/labels/\(labelId)", method: "DELETE")

        #if DEBUG
        Log.network.debug("Remove label response bytes: \(data.count, privacy: .public)")
        #endif

        // Check if this also just returns a confirmation instead of the updated task
        do {
            return try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)
        } catch {
            Log.network.debug("Remove label response not a task; fetching task separately")
            return try await getTask(taskId: taskId)
        }
    }

    func createLabel(title: String, hexColor: String, description: String? = nil) async throws -> Label {
        struct NewLabel: Encodable {
            let title: String
            let hex_color: String
            let description: String?
        }

        let newLabel = NewLabel(title: title, hex_color: hexColor, description: description)
        let data = try await request("labels", method: "PUT", body: newLabel)

        #if DEBUG
        Log.network.debug("Create label response bytes: \(data.count, privacy: .public)")
        #endif

        do {
            return try JSONDecoder.vikunja.decode(Label.self, from: data)
        } catch {
            Log.network.error("Label creation JSON decoding error: \(String(describing: error), privacy: .public)")
            if let decodingError = error as? DecodingError {
                Log.network.error("Label decoding error details: \(String(describing: decodingError), privacy: .public)")
            }
            throw error
        }
    }

    func updateLabel(labelId: Int, title: String, hexColor: String, description: String? = nil) async throws -> Label {
        struct UpdateLabel: Encodable {
            let title: String
            let hex_color: String
            let description: String?
        }

        let updateLabel = UpdateLabel(title: title, hex_color: hexColor, description: description)
        let data = try await request("labels/\(labelId)", method: "POST", body: updateLabel)

        #if DEBUG
        Log.network.debug("Update label response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode(Label.self, from: data)
    }

    func deleteLabel(labelId: Int) async throws {
        _ = try await request("labels/\(labelId)", method: "DELETE")

        #if DEBUG
        Log.network.debug("Label deleted: \(labelId, privacy: .public)")
        #endif
    }

    // MARK: - Reminders

    func addReminderToTask(taskId: Int, reminderDate: Date) async throws -> VikunjaTask {
        struct NewReminder: Encodable {
            let reminder: String
        }

        let formatter = ISO8601DateFormatter()
        let newReminder = NewReminder(reminder: formatter.string(from: reminderDate))

        _ = try await request("tasks/\(taskId)/reminders", method: "PUT", body: newReminder)

        // The API returns confirmation, fetch updated task
        return try await getTask(taskId: taskId)
    }

    func removeReminderFromTask(taskId: Int, reminderId: Int) async throws -> VikunjaTask {
        _ = try await request("tasks/\(taskId)/reminders/\(reminderId)", method: "DELETE")

        // Fetch updated task
        return try await getTask(taskId: taskId)
    }

    func deleteTask(taskId: Int) async throws {
        _ = try await request("tasks/\(taskId)", method: "DELETE")
    }

    // MARK: - Users (only available for username/password authentication)

    func searchUsers(query: String) async throws -> [VikunjaUser] {
        let queryItems = [URLQueryItem(name: "s", value: query)]
        let ep = Endpoint(method: "GET", pathComponents: ["users"], queryItems: queryItems)
        let data = try await request(ep)

        #if DEBUG
        Log.network.debug("User search response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode([VikunjaUser].self, from: data)
    }

    func assignUserToTask(taskId: Int, userId: Int) async throws -> VikunjaTask {
        struct UserAssignment: Encodable { let user_id: Int }
        _ = try await request("tasks/\(taskId)/assignees", method: "PUT",
                                body: UserAssignment(user_id: userId))

        // Fetch the updated task
        return try await getTask(taskId: taskId)
    }

    func removeUserFromTask(taskId: Int, userId: Int) async throws -> VikunjaTask {
        _ = try await request("tasks/\(taskId)/assignees/\(userId)", method: "DELETE")

        // Fetch the updated task
        return try await getTask(taskId: taskId)
    }

    func getTaskAssignees(taskId: Int) async throws -> [VikunjaUser] {
        let data = try await request("tasks/\(taskId)/assignees")

        #if DEBUG
        Log.network.debug("Task assignees response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode([VikunjaUser].self, from: data)
    }
    
    func getCurrentUser() async throws -> (id: Int, defaultProjectId: Int?) {
        struct CurrentUser: Codable {
            let id: Int
            let username: String
            let name: String?
            let email: String?
            let defaultProjectId: Int?
            
            enum CodingKeys: String, CodingKey {
                case id, username, name, email
                case defaultProjectId = "default_project_id"
            }
        }
        
        let data = try await request("/user", method: "GET")
        
        let user = try JSONDecoder().decode(CurrentUser.self, from: data)
        return (id: user.id, defaultProjectId: user.defaultProjectId)
        
    }

    // MARK: - Attachments

    /// Fetch attachments for a task.
    func getTaskAttachments(taskId: Int) async throws -> [TaskAttachment] {
        #if DEBUG
        Log.network.debug("Fetching attachments for task \(taskId, privacy: .public)")
        #endif

        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "\(taskId)", "attachments"])
        let data = try await request(ep)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            Log.network.debug("Attachments response: \(jsonString, privacy: .public)")
        }
        #endif

        let attachments = try JSONDecoder.vikunja.decode([TaskAttachment].self, from: data)

        #if DEBUG
        Log.network.debug("Decoded \(attachments.count, privacy: .public) attachments")
        #endif

        return attachments
    }

    /// Upload a file attachment for the given task.
    ///
    /// - Parameters:
    ///   - taskId: The task identifier.
    ///   - fileName: Name of the file as it should appear on the server.
    ///   - data: Raw file data to upload.
    ///   - mimeType: MIME type describing the data. Defaults to `application/octet-stream`.
    func uploadAttachment(taskId: Int, fileName: String, data: Data, mimeType: String = "application/octet-stream") async throws {
        #if DEBUG
        Log.network.debug("Starting attachment upload")
        Log.network.debug("Task ID: \(taskId, privacy: .public)")
        Log.network.debug("File name: \(fileName, privacy: .public)")
        Log.network.debug("MIME type: \(mimeType, privacy: .public)")
        Log.network.debug("Data size: \(data.count, privacy: .public) bytes")
        #endif

        let endpoint = Endpoint(method: "PUT", pathComponents: ["tasks", "\(taskId)", "attachments"])
        let url = try url(for: endpoint)

        #if DEBUG
        Log.network.debug("Upload URL: \(url.absoluteString, privacy: .public)")
        #endif

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = tokenProvider() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            Log.network.debug("Authorization header set")
            #endif
        }

        // Build multipart body
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        Log.network.debug("Using boundary: \(boundary, privacy: .public)")
        #endif

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))

        req.setValue(String(body.count), forHTTPHeaderField: "Content-Length")

        #if DEBUG
        Log.network.debug("Multipart body size: \(body.count, privacy: .public) bytes")
        Log.network.debug("Making upload request…")
        #endif

        let (respData, resp) = try await session.upload(for: req, from: body)

        #if DEBUG
        Log.network.debug("Upload request completed")
        #endif

        guard let http = resp as? HTTPURLResponse else {
            #if DEBUG
            Log.network.error("No HTTP response received during upload")
            #endif
            throw APIError.other("No HTTP response")
        }

        #if DEBUG
        Log.network.debug("HTTP status code: \(http.statusCode, privacy: .public)")
        if let responseString = String(data: respData, encoding: .utf8) {
            Log.network.debug("Response body: \(responseString, privacy: .public)")
        }
        #endif

        guard (200..<300).contains(http.statusCode) else {
            let message = extractErrorMessage(from: respData)
            if let message, !message.isEmpty {
                #if DEBUG
                Log.network.error("Upload failed with message: \(message, privacy: .public)")
                #endif
                throw APIError.other(message)
            } else {
                #if DEBUG
                Log.network.error("Upload failed with HTTP \(http.statusCode, privacy: .public)")
                #endif
                throw APIError.http(http.statusCode)
            }
        }

        #if DEBUG
        Log.network.debug("Upload completed successfully")
        #endif
    }

    /// Delete a task attachment.
    func deleteAttachment(taskId: Int, attachmentId: Int) async throws {
        let ep = Endpoint(method: "DELETE", pathComponents: ["tasks", "\(taskId)", "attachments", "\(attachmentId)"])
        _ = try await request(ep)
    }

    /// Download a task attachment.
    func downloadAttachment(taskId: Int, attachmentId: Int) async throws -> Data {
        #if DEBUG
        Log.network.debug("Downloading attachment \(attachmentId, privacy: .public) for task \(taskId, privacy: .public)")
        #endif

        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "\(taskId)", "attachments", "\(attachmentId)"])
        let data = try await request(ep)

        #if DEBUG
        Log.network.debug("Downloaded attachment data, size: \(data.count, privacy: .public) bytes")
        #endif

        return data
    }

    // MARK: - Comments

    /// Fetch comments for a task.
    func getTaskComments(taskId: Int) async throws -> [TaskComment] {
        #if DEBUG
        Log.network.debug("Fetching comments for task \(taskId, privacy: .public)")
        #endif

        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "\(taskId)", "comments"])
        let data = try await request(ep)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            Log.network.debug("Comments response: \(jsonString, privacy: .public)")
        }
        #endif

        let comments = try JSONDecoder.vikunja.decode([TaskComment].self, from: data)

        #if DEBUG
        Log.network.debug("Decoded \(comments.count, privacy: .public) comments")
        #endif

        return comments
    }

    // MARK: - Relations

    /// Get all relations for a task
    func getTaskRelations(taskId: Int) async throws -> [TaskRelation] {
        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "\(taskId)", "relations"])
        let data = try await request(ep)
        return try JSONDecoder.vikunja.decode([TaskRelation].self, from: data)
    }

    /// Add a relation between tasks
    func addTaskRelation(taskId: Int, otherTaskId: Int, relationKind: TaskRelationKind) async throws {
        struct RelationBody: Encodable { let other_task_id: Int; let relation_kind: String }
        let body = RelationBody(other_task_id: otherTaskId, relation_kind: relationKind.rawValue)
        let ep = Endpoint(method: "PUT", pathComponents: ["tasks", "\(taskId)", "relations"])
        _ = try await request(ep, body: body)
    }

    /// Remove a relation between tasks
    func removeTaskRelation(taskId: Int, otherTaskId: Int, relationKind: TaskRelationKind) async throws {
        struct RelationBody: Encodable { let other_task_id: Int; let relation_kind: String }
        let body = RelationBody(other_task_id: otherTaskId, relation_kind: relationKind.rawValue)
        let ep = Endpoint(method: "DELETE", pathComponents: ["tasks", "\(taskId)", "relations"])
        _ = try await request(ep, body: body)
    }

    /// Get comment count for a task (lightweight version).
    func getTaskCommentCount(taskId: Int) async throws -> Int {
        #if DEBUG
        Log.network.debug("Fetching comment count for task \(taskId, privacy: .public)")
        #endif

        do {
            let comments = try await getTaskComments(taskId: taskId)
            let count = comments.count

            #if DEBUG
            Log.network.debug("Task \(taskId, privacy: .public) has \(count, privacy: .public) comments")
            #endif

            return count
        } catch {
            // Handle "no comments" case gracefully
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("404") || errorMessage.contains("not found") ||
               errorMessage.contains("no such file") || errorMessage.contains("missing") ||
               errorMessage.contains("couldn't be read") {
                #if DEBUG
                Log.network.debug("Task \(taskId, privacy: .public) has no comments (404/not found)")
                #endif
                return 0
            } else {
                throw error
            }
        }
    }

    /// Add a comment to a task.
    func addTaskComment(taskId: Int, comment: String) async throws -> TaskComment {
        #if DEBUG
        Log.network.debug("Adding comment to task \(taskId, privacy: .public)")
        #endif

        struct NewComment: Encodable {
            let comment: String
        }

        let newComment = NewComment(comment: comment)
        let ep = Endpoint(method: "PUT", pathComponents: ["tasks", "\(taskId)", "comments"])
        let data = try await request(ep, body: newComment)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            Log.network.debug("Add comment response: \(jsonString, privacy: .public)")
        }
        #endif

        let addedComment = try JSONDecoder.vikunja.decode(TaskComment.self, from: data)

        #if DEBUG
        Log.network.debug("Successfully added comment with ID: \(addedComment.id, privacy: .public)")
        #endif

        return addedComment
    }

    /// Delete a comment from a task.
    func deleteTaskComment(taskId: Int, commentId: Int) async throws {
        #if DEBUG
        Log.network.debug("Deleting comment \(commentId, privacy: .public) from task \(taskId, privacy: .public)")
        #endif

        let ep = Endpoint(method: "DELETE", pathComponents: ["tasks", "\(taskId)", "comments", "\(commentId)"])
        _ = try await request(ep)

        #if DEBUG
        Log.network.debug("Successfully deleted comment \(commentId, privacy: .public)")
        #endif
    }

    // MARK: - Favorites

    func getFavoriteTasks() async throws -> [VikunjaTask] {
        // Server-side filtering by favorites is not supported; fetch all and filter client-side
        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"])
        let data = try await request(ep)

        #if DEBUG
        Log.network.debug("Favorite tasks (client-side) response bytes: \(data.count, privacy: .public)")
        #endif

        let allTasks = try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
        let favoriteTasks = allTasks.filter { $0.isFavorite }

        #if DEBUG
        Log.network.debug("Client-side: Got \(allTasks.count, privacy: .public) total tasks, \(favoriteTasks.count, privacy: .public) favorites") // swiftlint:disable:this line_length
        #endif

        return favoriteTasks
    }

    // MARK: - Task Search

    /// Search tasks across all projects
    func searchTasks(query: String, page: Int = 1, perPage: Int = 25) async throws -> [VikunjaTask] {
        // 1) Try native search param (?s=)
        do {
            let items = [
                URLQueryItem(name: "s", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
            let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"], queryItems: items)
            let data = try await request(ep)
            return try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
        } catch {
            #if DEBUG
            Log.network.error("searchTasks: ?s= failed with error: \(String(describing: error), privacy: .public)")
            #endif
        }

        // 2) Try filter syntax on server (title/description like)
        do {
            let escaped = query.replacingOccurrences(of: "\"", with: "\\\"")
            let filterString = "title like \"%\(escaped)%\" || description like \"%\(escaped)%\""
            let items = [
                URLQueryItem(name: "filter", value: filterString),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
            let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"], queryItems: items)
            let data = try await request(ep)
            return try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
        } catch {
            #if DEBUG
            Log.network.error("searchTasks: filter fallback failed with error: \(String(describing: error), privacy: .public)")
            #endif
        }

        // 3) Final fallback: fetch all tasks and filter locally (title/description contains)
        let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"])
        let data = try await request(ep)
        let all = try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
        let q = query.lowercased()
        return all.filter { t in
            let inTitle = t.title.lowercased().contains(q)
            let inDesc = (t.description ?? "").lowercased().contains(q)
            return inTitle || inDesc
        }
    }

    func toggleTaskFavorite(task: VikunjaTask) async throws -> VikunjaTask {
        // Create a copy with toggled favorite status
        var updatedTask = task
        updatedTask.isFavorite = !task.isFavorite

        #if DEBUG
        Log.network.debug("Toggling favorite for task: id=\(task.id, privacy: .public) title=\(task.title, privacy: .public) current=\(task.isFavorite, privacy: .public) new=\(updatedTask.isFavorite, privacy: .public) createdBy=\(task.createdBy?.name ?? "nil", privacy: .public) assignees=\(task.assignees?.count ?? 0, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        // Send the complete task object to preserve all fields
        let data = try await request("tasks/\(task.id)", method: "POST", body: updatedTask)

        #if DEBUG
        Log.network.debug("Toggle favorite response bytes: \(data.count, privacy: .public)")
        if let jsonString = String(data: data, encoding: .utf8) {
            Log.network.debug("Toggle favorite API response: \(jsonString, privacy: .public)")
        }
        #endif

        let finalTask = try JSONDecoder.vikunja.decode(VikunjaTask.self, from: data)

        #if DEBUG
        Log.network.debug("Final task after favorite toggle: id=\(finalTask.id, privacy: .public) title=\(finalTask.title, privacy: .public) isFavorite=\(finalTask.isFavorite, privacy: .public) createdBy=\(finalTask.createdBy?.name ?? "nil", privacy: .public) assignees=\(finalTask.assignees?.count ?? 0, privacy: .public)") // swiftlint:disable:this line_length
        #endif

        return finalTask
    }

    func toggleTaskFavorite(taskId: Int, currentFavoriteStatus: Bool) async throws -> VikunjaTask {
        // Fallback method that fetches the task first
        let currentTask = try await getTask(taskId: taskId)
        return try await toggleTaskFavorite(task: currentTask)
    }

    // Convenience method that fetches current status first
    func toggleTaskFavorite(taskId: Int) async throws -> VikunjaTask {
        let currentTask = try await getTask(taskId: taskId)
        return try await toggleTaskFavorite(taskId: taskId, currentFavoriteStatus: currentTask.isFavorite)
    }
}

// MARK: - JSON helpers
extension JSONDecoder {
    static var vikunja: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
extension JSONEncoder {
    static var vikunja: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

// MARK: - Background sync helpers
extension VikunjaAPI {
    /// Fetch all tasks updated since ISO8601 cursor across all projects.
    /// This uses server filtering when available and falls back to client-side filtering.
    func fetchAllTasksUpdatedSince(sinceISO8601: String?) async throws -> [VikunjaTask] {
        // Try paginated server-side filtering first
        var results: [VikunjaTask] = []
        var page = 1
        let perPage = 200
        var usedServerFilter = false
        if let sinceISO8601 {
            usedServerFilter = true
            while true {
                let items = [
                    URLQueryItem(name: "updated_since", value: sinceISO8601),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "per_page", value: String(perPage))
                ]
                do {
                    let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"], queryItems: items)
                    let data = try await request(ep)
                    let pageTasks = try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
                    results += pageTasks
                    if pageTasks.count < perPage { break }
                    page += 1
                } catch {
                    #if DEBUG
                    Log.network.error("fetchAllTasksUpdatedSince: server filter failed on page \(page, privacy: .public): \(String(describing: error), privacy: .public)") // swiftlint:disable:this line_length
                    #endif
                    usedServerFilter = false
                    break
                }
            }
        }
        if usedServerFilter { return results }

        // Fallback: fetch all (paginated) and filter locally
        results.removeAll(keepingCapacity: true)
        page = 1
        while true {
            let items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
            let ep = Endpoint(method: "GET", pathComponents: ["tasks", "all"], queryItems: items)
            let data = try await request(ep)
            let pageTasks = try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
            results += pageTasks
            if pageTasks.count < perPage { break }
            page += 1
        }
        guard let sinceISO8601 else { return results }
        let iso = ISO8601DateFormatter()
        let sinceDate = iso.date(from: sinceISO8601)
        if let s = sinceDate {
            return results.filter { t in
                guard let u = t.updatedAt else { return true }
                return u > s
            }
        }
        return results
    }
}
