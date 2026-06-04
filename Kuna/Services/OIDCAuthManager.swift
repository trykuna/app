// Services/OIDCAuthManager.swift
import AuthenticationServices
import Foundation

enum OIDCError: Error, LocalizedError, Equatable {
    case cancelled
    case missingToken
    case invalidCallbackURL

    var errorDescription: String? {
        switch self {
        case .cancelled:          return String(localized: "auth.oidc.error.cancelled")
        case .missingToken:       return String(localized: "auth.oidc.error.missingToken")
        case .invalidCallbackURL: return String(localized: "auth.oidc.error.invalidCallback")
        }
    }
}

@MainActor
final class OIDCAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {

    func authenticate(authURL: URL, callbackScheme: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
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
                guard let token = Self.extractToken(from: callbackURL) else {
                    continuation.resume(throwing: OIDCError.missingToken)
                    return
                }
                continuation.resume(returning: token)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window as the presentation anchor
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }

    // Extract token from callback URL.
    // Vikunja may return the token in different places depending on version:
    //   kuna://auth/callback?token=...
    //   kuna://auth/callback#token=...  (fragment)
    private static func extractToken(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check query parameters first
            if let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
               !token.isEmpty {
                return token
            }
            // Check URL fragment (hash)
            if let fragment = components.fragment {
                let fragmentComponents = URLComponents(string: "?\(fragment)")
                if let token = fragmentComponents?.queryItems?.first(where: { $0.name == "token" })?.value,
                   !token.isEmpty {
                    return token
                }
            }
        }
        return nil
    }
}
