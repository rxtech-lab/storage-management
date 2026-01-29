//
//  OAuthManager.swift
//  RxStorageCore
//
//  OAuth 2.0 authentication manager with PKCE flow
//

import Foundation
import AuthenticationServices
import Observation

#if canImport(UIKit)
import UIKit
#endif

/// User information from OAuth
public struct User: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let email: String?
    public let image: String?

    public init(id: String, name: String?, email: String?, image: String?) {
        self.id = id
        self.name = name
        self.email = email
        self.image = image
    }
}

/// OAuth authentication manager
@MainActor
@Observable
public final class OAuthManager {
    /// Shared singleton instance
    public static let shared = OAuthManager()

    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage
    private let apiClient: APIClient

    /// Whether user is currently authenticated
    public private(set) var isAuthenticated: Bool = false

    /// Current authenticated user
    public private(set) var currentUser: User?

    public init(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared,
        apiClient: APIClient = .shared
    ) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage
        self.apiClient = apiClient

        // Check if already authenticated
        Task {
            await checkAuthenticationStatus()
        }

        // Observe auth session expiration notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthSessionExpired),
            name: .authSessionExpired,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Handle auth session expiration notification
    @objc private func handleAuthSessionExpired() {
        Task {
            await handleSessionExpiration()
        }
    }

    /// Clear tokens and update auth state when session expires
    private func handleSessionExpiration() async {
        try? await tokenStorage.clearAll()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - Authentication

    /// Initiate OAuth authentication flow
    public func authenticate() async throws {
        // Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Build authorization URL
        var urlComponents = URLComponents(string: configuration.authIssuer)!
        urlComponents.path = "/api/oauth/authorize"
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.authClientID),
            URLQueryItem(name: "redirect_uri", value: configuration.authRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.authScopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = urlComponents.url else {
            throw OAuthError.invalidURL
        }

        // Present authentication session
        let callbackURLScheme = configuration.authRedirectURI.components(separatedBy: "://").first

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            Task { @MainActor in
                do {
                    if let error = error {
                        if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                            throw OAuthError.userCancelled
                        }
                        throw OAuthError.authenticationFailed(error)
                    }

                    guard let callbackURL = callbackURL else {
                        throw OAuthError.invalidCallback
                    }

                    try await self.handleCallback(url: callbackURL, codeVerifier: codeVerifier)
                } catch {
                    print("Authentication error: \(error)")
                }
            }
        }

        // Set presentation context provider
        #if canImport(UIKit)
        let contextProvider = WebAuthenticationPresentationContextProvider()
        session.presentationContextProvider = contextProvider
        #endif
        session.prefersEphemeralWebBrowserSession = false

        guard session.start() else {
            throw OAuthError.sessionStartFailed
        }
    }

    /// Handle OAuth callback URL
    private func handleCallback(url: URL, codeVerifier: String) async throws {
        // Extract authorization code from callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.invalidCallback
        }

        // Exchange authorization code for tokens
        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    }

    /// Exchange authorization code for access and refresh tokens
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var urlComponents = URLComponents(string: configuration.authIssuer)!
        urlComponents.path = "/api/oauth/token"

        guard let url = urlComponents.url else {
            throw OAuthError.invalidURL
        }

        print("Token exchange URL: \(url)")
        print("Client ID: \(configuration.authClientID)")
        print("Redirect URI: \(configuration.authRedirectURI)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.authRedirectURI,
            "client_id": configuration.authClientID,
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Perform token exchange
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Token exchange: Invalid response type")
            throw OAuthError.tokenExchangeFailed
        }

        print("Token exchange response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("Token exchange error response: \(errorString)")
            }
            throw OAuthError.tokenExchangeFailed
        }

        // Decode token response
        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save tokens
        try await tokenStorage.saveAccessToken(tokenResponse.access_token)
        try await tokenStorage.saveRefreshToken(tokenResponse.refresh_token)

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        try await tokenStorage.saveExpiresAt(expiresAt)

        // Fetch user info
        try await fetchUserInfo()

        isAuthenticated = true
    }

    /// Fetch user information from userinfo endpoint
    private func fetchUserInfo() async throws {
        guard let accessToken = await tokenStorage.getAccessToken() else {
            throw OAuthError.noAccessToken
        }

        var urlComponents = URLComponents(string: configuration.authIssuer)!
        urlComponents.path = "/api/oauth/userinfo"

        guard let url = urlComponents.url else {
            throw OAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.userInfoFetchFailed
        }

        // Decode user info
        struct UserInfo: Codable {
            let sub: String
            let name: String?
            let email: String?
            let picture: String?
        }

        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)

        currentUser = User(
            id: userInfo.sub,
            name: userInfo.name,
            email: userInfo.email,
            image: userInfo.picture
        )
    }

    /// Logout user
    public func logout() async {
        try? await tokenStorage.clearAll()
        isAuthenticated = false
        currentUser = nil
    }

    /// Refresh access token if expired
    public func refreshTokenIfNeeded() async throws {
        if await tokenStorage.isTokenExpired() {
            try await apiClient.refreshAccessToken()
            try await fetchUserInfo()
        }
    }

    /// Current access token
    public func getAccessToken() async -> String? {
        await tokenStorage.getAccessToken()
    }

    // MARK: - Private Helpers

    private func checkAuthenticationStatus() async {
        if let _ = await tokenStorage.getAccessToken(), await !tokenStorage.isTokenExpired() {
            isAuthenticated = true
            try? await fetchUserInfo()
        }
    }

    // MARK: - PKCE Helpers

    nonisolated private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to encode code verifier")
        }

        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// Need to import CommonCrypto for SHA256
import CommonCrypto

// MARK: - OAuth Errors

public enum OAuthError: LocalizedError, @unchecked Sendable {
    case invalidURL
    case userCancelled
    case authenticationFailed(Error)
    case invalidCallback
    case sessionStartFailed
    case tokenExchangeFailed
    case noAccessToken
    case userInfoFetchFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid authentication URL"
        case .userCancelled:
            return "Authentication cancelled by user"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .invalidCallback:
            return "Invalid authentication callback"
        case .sessionStartFailed:
            return "Failed to start authentication session"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .noAccessToken:
            return "No access token available"
        case .userInfoFetchFailed:
            return "Failed to fetch user information"
        }
    }
}

// MARK: - Presentation Context Provider

#if canImport(UIKit)
/// Presentation context provider for ASWebAuthenticationSession
private class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        // Fallback to any window
        return UIApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
#endif
