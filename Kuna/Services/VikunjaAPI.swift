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
    case badURL, http(Int), decoding, missingToken, other(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL"
        case .http(let code): return "HTTP \(code)"
        case .decoding: return "Decoding failed"
        case .missingToken: return "No auth token"
        case .other(let s): return s
        }
    }
}

final class VikunjaAPI {
    // Build URL from Endpoint

    // Backward-compatible string-path request kept for now
    @discardableResult
    private func request(_ path: String,
                         method: String = "GET",
                         body: (some Encodable)? = Optional<String>.none) async throws -> Data {
        return try await request(Endpoint(method: method, pathComponents: path.split(separator: "/").map(String.init)), body: body)
    }

    // New Endpoint-based request
    private func request(_ endpoint: Endpoint, body: (some Encodable)? = Optional<String>.none) async throws -> Data {
        let url = try url(for: endpoint)
        Log.network.debug("Request: \(endpoint.method, privacy: .public) \(url.absoluteString, privacy: .public)")

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = tokenProvider() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            Log.network.debug("Authorization header set for endpoint \(endpoint.pathComponents.joined(separator: "/"), privacy: .public)")
            #endif
        } else {
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
                Log.network.debug("Response: status=\(http.statusCode, privacy: .public) url=\(url.absoluteString, privacy: .public)")
                if (200..<300).contains(http.statusCode) {
                    return data
                }
                if isGet && (http.statusCode == 500 || http.statusCode == 502 || http.statusCode == 503 || http.statusCode == 504) && attempt < 3 {
                    let delay = UInt64(pow(2.0, Double(attempt - 1)) * 0.3 * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                if LogConfig.verboseNetwork {
                    Log.network.debug("HTTP error status=\(http.statusCode, privacy: .public)")
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



    private let config: VikunjaConfig
    /// Injected so this layer never touches Keychain directly.
    private let tokenProvider: () -> String?
    private let session: URLSession


    init(config: VikunjaConfig, tokenProvider: @escaping () -> String?, session: URLSession = .shared) {
        self.config = config
        self.tokenProvider = tokenProvider
        self.session = session
    }



    // MARK: - Auth
    func login(username: String, password: String) async throws -> String {
        struct LoginBody: Encodable { let username: String; let password: String }
        let data = try await request("login", method: "POST", body: LoginBody(username: username, password: password))

        // Optionally log response size in debug (avoid body content)
        #if DEBUG
        Log.network.debug("Login response bytes: \(data.count, privacy: .public)")
        #endif

        let auth = try JSONDecoder.vikunja.decode(AuthResponse.self, from: data)
        // Return token to caller (AppState) who will persist it to Keychain
        return auth.token
    }

    // MARK: - Projects
    func fetchProjects() async throws -> [Project] {
        let data = try await request(Endpoint(method: "GET", pathComponents: ["projects"]))

        #if DEBUG
        Log.network.debug("Projects response bytes: \(data.count, privacy: .public)")
        #endif

        return try JSONDecoder.vikunja.decode([Project].self, from: data)
    }

    func createProject(title: String, description: String? = nil) async throws -> Project {
        struct NewProject: Encodable {
            let title: String
            let description: String?
        }
        let newProject = NewProject(title: title, description: description)

        #if DEBUG
        Log.network.debug("Creating project body size bytes: \((try? JSONEncoder.vikunja.encode(newProject).count) ?? 0, privacy: .public)")
        #endif

        let data = try await request("projects", method: "PUT", body: newProject)
        #if DEBUG
        Log.network.debug("Create project response bytes: \(data.count, privacy: .public)")
        #endif
        return try JSONDecoder.vikunja.decode(Project.self, from: data)
    }

    // MARK: - Tasks
    // Optional query-enabled variant
    func fetchTasks(projectId: Int, queryItems: [URLQueryItem]) async throws -> [VikunjaTask] {
        let ep = Endpoint(method: "GET", pathComponents: ["projects", String(projectId), "tasks"], queryItems: queryItems)
        let data = try await request(ep)
        #if DEBUG
        Log.network.debug("Tasks(response) bytes: \(data.count, privacy: .public)")
        #endif
        return try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
    }

    // MARK: - Tasks
    func fetchTasks(projectId: Int) async throws -> [VikunjaTask] {
        let ep = Endpoint(method: "GET", pathComponents: ["projects", String(projectId), "tasks"])
        let data = try await request(ep)

        // Debug: print the raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("Tasks Response: \(responseString)")
        }

        do {
            return try JSONDecoder.vikunja.decode([VikunjaTask].self, from: data)
        } catch {
            print("JSON Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding Error Details: \(decodingError)")
            }
            throw error
        }
    }

    func createTask(projectId: Int, title: String, description: String?) async throws -> VikunjaTask {
        struct NewTask: Encodable {
            let title: String
            let description: String?
        }
        let newTask = NewTask(title: title, description: description)

        #if DEBUG
        Log.network.debug("Creating task body size bytes: \((try? JSONEncoder.vikunja.encode(newTask).count) ?? 0, privacy: .public)")
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
        Log.network.debug("Updating task body size bytes: \((try? JSONEncoder.vikunja.encode(updated).count) ?? 0, privacy: .public)")
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
            print("Updating task with body: \(jsonString)")
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

        return try JSONDecoder.vikunja.decode([Label].self, from: data)
    }

    func addLabelToTask(taskId: Int, labelId: Int) async throws -> VikunjaTask {
        struct LabelAssignment: Encodable { let label_id: Int }
        let _ = try await request("tasks/\(taskId)/labels", method: "PUT",
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

    // MARK: - Reminders
    func addReminderToTask(taskId: Int, reminderDate: Date) async throws -> VikunjaTask {
        struct NewReminder: Encodable {
            let reminder: String
        }

        let formatter = ISO8601DateFormatter()
        let newReminder = NewReminder(reminder: formatter.string(from: reminderDate))

        let _ = try await request("tasks/\(taskId)/reminders", method: "PUT", body: newReminder)

        // The API returns confirmation, fetch updated task
        return try await getTask(taskId: taskId)
    }

    func removeReminderFromTask(taskId: Int, reminderId: Int) async throws -> VikunjaTask {
        let _ = try await request("tasks/\(taskId)/reminders/\(reminderId)", method: "DELETE")

        // Fetch updated task
        return try await getTask(taskId: taskId)
    }

    func deleteTask(taskId: Int) async throws {
        let _ = try await request("tasks/\(taskId)", method: "DELETE")
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
