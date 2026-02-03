//
//  OAuthManager.swift
//  RxStorageCore
//
//  OAuth 2.0 authentication manager with PKCE flow
//

import Foundation
import AuthenticationServices
import Logging
import Observation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Authentication state representing the current auth status
public enum AuthenticationState: Sendable {
    /// Initial state - authentication check is in progress
    case unknown
    /// User is authenticated and has valid tokens
    case authenticated
    /// User is not authenticated (no tokens or expired)
    case unauthenticated
}

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
    private let logger = Logger(label: "com.rxlab.rxstorage.OAuthManager")

    /// Timer for periodic token refresh checks
    private var refreshTimer: Timer?

    /// Presentation context provider - must be retained during auth session (iOS only)
    #if os(iOS)
    private var presentationContextProvider: WebAuthenticationPresentationContextProvider?
    #endif

    /// Web auth window controller for macOS
    #if os(macOS)
    private var webAuthController: WebAuthWindowController?
    #endif

    /// Interval between token refresh checks (5 minutes)
    private let refreshCheckInterval: TimeInterval = 300

    /// Current authentication state
    public private(set) var authState: AuthenticationState = .unknown

    /// Whether user is currently authenticated (backward-compatible computed property)
    public var isAuthenticated: Bool {
        authState == .authenticated
    }

    /// Current authenticated user
    public private(set) var currentUser: User?

    public init(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage

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
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
        }
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
        stopRefreshTimer()
        try? await tokenStorage.clearAll()
        authState = .unauthenticated
        currentUser = nil
    }

    // MARK: - Token Refresh Timer

    /// Start the periodic token refresh timer
    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performPeriodicRefreshCheck()
            }
        }
    }

    /// Stop the refresh timer
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Perform periodic token refresh check
    private func performPeriodicRefreshCheck() async {
        guard authState == .authenticated else { return }

        do {
            try await refreshTokenIfNeeded()
        } catch {
            logger.warning("Periodic token refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Authentication

    /// Initiate OAuth authentication flow
    /// This method waits for the entire authentication flow to complete before returning
    public func authenticate() async throws {
        logger.info("Starting authentication flow, isMainThread: \(Thread.isMainThread)")

        // Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        logger.debug("PKCE parameters generated")

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

        let callbackURLScheme = configuration.authRedirectURI.components(separatedBy: "://").first ?? "rxstorage"
        logger.info("Auth URL: \(authURL), callback scheme: \(callbackURLScheme)")

        // Platform-specific authentication
        #if os(macOS)
        // Use WKWebView-based authentication on macOS
        logger.info("Using WKWebView authentication for macOS")
        let controller = WebAuthWindowController(authURL: authURL, callbackScheme: callbackURLScheme)
        self.webAuthController = controller

        do {
            let callbackURL = try await controller.start()
            self.webAuthController = nil
            logger.info("Callback URL: \(callbackURL)")
            try await handleCallback(url: callbackURL, codeVerifier: codeVerifier)
            logger.info("Authentication complete")
        } catch {
            self.webAuthController = nil
            throw error
        }
        #else
        // Use ASWebAuthenticationSession on iOS (supports passkeys)
        logger.debug("Creating presentation context provider")
        self.presentationContextProvider = WebAuthenticationPresentationContextProvider()
        logger.debug("Presentation context provider created")

        logger.debug("Entering continuation")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logger.info("Inside continuation, isMainThread: \(Thread.isMainThread)")

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                self?.logger.info("Callback received, isMainThread: \(Thread.isMainThread)")

                guard let self = self else {
                    continuation.resume(throwing: OAuthError.authenticationFailed(NSError(domain: "OAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"])))
                    return
                }

                Task { @MainActor in
                    defer { self.presentationContextProvider = nil }

                    do {
                        if let error = error {
                            self.logger.error("Auth error: \(error.localizedDescription)")
                            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                                continuation.resume(throwing: OAuthError.userCancelled)
                                return
                            }
                            continuation.resume(throwing: OAuthError.authenticationFailed(error))
                            return
                        }

                        guard let callbackURL = callbackURL else {
                            self.logger.error("No callback URL received")
                            continuation.resume(throwing: OAuthError.invalidCallback)
                            return
                        }

                        self.logger.info("Callback URL: \(callbackURL)")
                        try await self.handleCallback(url: callbackURL, codeVerifier: codeVerifier)
                        self.logger.info("Authentication complete")
                        continuation.resume()
                    } catch {
                        self.logger.error("Callback handling error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }

            logger.debug("Setting presentation context provider")
            session.presentationContextProvider = self.presentationContextProvider
            logger.debug("Setting ephemeral session")
            session.prefersEphemeralWebBrowserSession = true

            logger.info("Starting ASWebAuthenticationSession")
            if !session.start() {
                logger.error("Session failed to start")
                continuation.resume(throwing: OAuthError.sessionStartFailed)
            } else {
                logger.info("Session started successfully")
            }
        }
        #endif
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

        authState = .authenticated
        startRefreshTimer()
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
        stopRefreshTimer()
        try? await tokenStorage.clearAll()
        authState = .unauthenticated
        currentUser = nil
    }

    /// Refresh access token if expired
    public func refreshTokenIfNeeded() async throws {
        if await tokenStorage.isTokenExpired() {
            try await performTokenRefresh()
            try await fetchUserInfo()
        }
    }

    /// Refresh access token using refresh token
    private func performTokenRefresh() async throws {
        guard let refreshToken = await tokenStorage.getRefreshToken() else {
            throw OAuthError.noAccessToken
        }

        // Build token refresh request
        var urlComponents = URLComponents(string: configuration.authIssuer)!
        urlComponents.path = "/api/oauth/token"

        guard let url = urlComponents.url else {
            throw OAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.authClientID,
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Perform token refresh
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed
        }

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("Token refresh failed: \(errorString)")
            }
            throw OAuthError.tokenExchangeFailed
        }

        // Decode token response
        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save new tokens
        try await tokenStorage.saveAccessToken(tokenResponse.access_token)

        if let newRefreshToken = tokenResponse.refresh_token {
            try await tokenStorage.saveRefreshToken(newRefreshToken)
        }

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        try await tokenStorage.saveExpiresAt(expiresAt)
    }

    /// Current access token
    public func getAccessToken() async -> String? {
        await tokenStorage.getAccessToken()
    }

    // MARK: - Private Helpers

    private func checkAuthenticationStatus() async {
        // Check if we have an access token
        guard let _ = await tokenStorage.getAccessToken() else {
            authState = .unauthenticated
            return
        }

        // If token is not expired, we're good
        if await !tokenStorage.isTokenExpired() {
            authState = .authenticated
            startRefreshTimer()
            try? await fetchUserInfo()
            return
        }

        // Token is expired - try to refresh if we have a refresh token
        guard await tokenStorage.getRefreshToken() != nil else {
            authState = .unauthenticated
            return
        }

        // Attempt to refresh the token
        do {
            try await performTokenRefresh()
            try await fetchUserInfo()
            authState = .authenticated
            startRefreshTimer()
        } catch {
            // Refresh failed - clear tokens and require re-login
            try? await tokenStorage.clearAll()
            authState = .unauthenticated
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

// MARK: - Presentation Context Provider (iOS only)

#if os(iOS)
/// Presentation context provider for ASWebAuthenticationSession
/// Simply returns a new ASPresentationAnchor - the framework handles platform-specific details
private class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let logger = Logger(label: "com.rxlab.rxstorage.WebAuthContextProvider")

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        logger.info("presentationAnchor called, isMainThread: \(Thread.isMainThread)")
        // Simply return a new ASPresentationAnchor - the framework will use an appropriate
        // presentation anchor for the current platform automatically
        return ASPresentationAnchor()
    }
}
#endif
