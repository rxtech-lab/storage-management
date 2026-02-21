//
//  AppConfiguration.swift
//  RxStorageCore
//
//  Configuration manager that reads settings from Info.plist
//

import Foundation

/// Application configuration loaded from Info.plist
@Observable
public class AppConfiguration: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = AppConfiguration()

    /// API base URL (e.g., "https://api.example.com" or "http://localhost:3000")
    public let apiBaseURL: String

    /// OAuth issuer URL (e.g., "https://auth.rxlab.app")
    public let authIssuer: String

    /// OAuth client ID
    public let authClientID: String

    /// OAuth redirect URI (e.g., "rxstorage://oauth/callback")
    public let authRedirectURI: String

    /// OAuth scopes
    public let authScopes: [String]

    private init() {
        let infoPlist = Bundle.main.infoDictionary

        // Check if API_BASE_URL is configured - if not, use test defaults
        // This handles SPM test environments where Info.plist is not available
        if let baseURL = infoPlist?["API_BASE_URL"] as? String, !baseURL.isEmpty {
            // Production/development environment with proper Info.plist
            apiBaseURL = baseURL

            guard let issuer = infoPlist?["AUTH_ISSUER"] as? String, !issuer.isEmpty else {
                fatalError("AUTH_ISSUER not configured in Info.plist")
            }
            authIssuer = issuer

            guard let clientID = infoPlist?["AUTH_CLIENT_ID"] as? String, !clientID.isEmpty else {
                fatalError("AUTH_CLIENT_ID not configured in Info.plist")
            }
            authClientID = clientID

            guard let redirectURI = infoPlist?["AUTH_REDIRECT_URI"] as? String, !redirectURI.isEmpty else {
                fatalError("AUTH_REDIRECT_URI not configured in Info.plist")
            }
            authRedirectURI = redirectURI

            if let scopesString = infoPlist?["AUTH_SCOPES"] as? String {
                authScopes = scopesString.split(separator: " ").map(String.init)
            } else {
                authScopes = ["openid", "email", "profile", "offline_access"]
            }
        } else {
            // Test environment - use placeholder values
            apiBaseURL = "http://localhost:3000"
            authIssuer = "https://auth.test.local"
            authClientID = "test_client_id"
            authRedirectURI = "rxstorage://oauth/callback"
            authScopes = ["openid", "email", "profile", "offline_access"]
        }
    }

    /// RxAuthSwift configuration derived from Info.plist values
    public var rxAuthConfiguration: RxAuthConfiguration {
        RxAuthConfiguration(
            issuer: authIssuer,
            clientID: authClientID,
            redirectURI: authRedirectURI,
            scopes: authScopes,
            keychainServiceName: "com.rxlab.RxStorage"
        )
    }

    /// Full API URL for a given path
    public func apiURL(for path: String) -> URL? {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(apiBaseURL)\(cleanPath)")
    }
}
