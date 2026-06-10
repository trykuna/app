// Services/OIDCAuthManager.swift
import AuthenticationServices
import Foundation

enum OIDCError: Error, LocalizedError, Equatable {
    case cancelled
    case missingCode
    case stateMismatch
    case invalidCallbackURL
    case badAuthURL

    var errorDescription: String? {
        switch self {
        case .cancelled:           return String(localized: "auth.oidc.error.cancelled")
        case .missingCode:         return String(localized: "auth.oidc.error.missingCode")
        case .stateMismatch:       return String(localized: "auth.oidc.error.stateMismatch")
        case .invalidCallbackURL:  return String(localized: "auth.oidc.error.invalidCallback")
        case .badAuthURL:          return String(localized: "auth.oidc.error.badAuthURL")
        }
    }
}

let defaultOIDCRedirectURI = "kuna://auth/callback"

@MainActor
final class OIDCAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {

    /// Opens a browser for the given OIDC provider, captures the authorization code,
    /// then returns it. The caller is responsible for exchanging the code with Vikunja.
    func getAuthorizationCode(for provider: OIDCProvider, redirectURI: String) async throws -> String {
        guard var components = URLComponents(string: provider.authUrl) else {
            throw OIDCError.badAuthURL
        }

        // Generate a random state value to protect against CSRF
        let state = UUID().uuidString

        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "client_id",     value: provider.clientId),
            URLQueryItem(name: "redirect_uri",  value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope",         value: provider.scope),
            URLQueryItem(name: "state",         value: state),
        ]

        guard let authURL = components.url else {
            throw OIDCError.badAuthURL
        }

        let callbackScheme = URL(string: redirectURI)?.scheme ?? "kuna"
        let callbackURL = try await openBrowser(to: authURL, callbackScheme: callbackScheme)

        guard let returnedComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw OIDCError.invalidCallbackURL
        }

        let items = returnedComponents.queryItems ?? []

        // Verify state to prevent CSRF
        let returnedState = items.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw OIDCError.stateMismatch
        }

        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OIDCError.missingCode
        }

        return code
    }

    private func openBrowser(to url: URL, callbackScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OIDCError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: OIDCError.invalidCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
