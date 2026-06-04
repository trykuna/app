// Models/VikunjaServerInfo.swift
import Foundation

struct VikunjaServerInfo: Decodable {
    let version: String?
    let auth: AuthInfo?

    struct AuthInfo: Decodable {
        let localEnabled: Bool?
        let openidConnect: OpenIDConnectInfo?

        enum CodingKeys: String, CodingKey {
            case localEnabled = "local_enabled"
            case openidConnect = "openid_connect"
        }
    }

    struct OpenIDConnectInfo: Decodable {
        let enabled: Bool
        let providers: [OIDCProvider]?
    }
}

struct OIDCProvider: Decodable, Identifiable {
    let name: String
    let key: String
    /// Authorization endpoint URL (e.g. https://sso.example.com/oauth/authorize)
    let authUrl: String
    let clientId: String
    let scope: String

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case name
        case key
        case authUrl = "auth_url"
        case clientId = "client_id"
        case scope
    }
}
