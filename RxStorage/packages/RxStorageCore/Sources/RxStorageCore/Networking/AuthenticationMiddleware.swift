//
//  AuthenticationMiddleware.swift
//  RxStorageCore
//
//  Middleware that injects Bearer token and handles automatic token refresh
//

import Foundation
import HTTPTypes
import Logging
import OpenAPIRuntime
import RxAuthSwift

/// Middleware that injects Bearer token into requests and handles token refresh
public actor AuthenticationMiddleware: ClientMiddleware {
    private let tokenStorage: TokenStorageProtocol
    private let configuration: RxAuthConfiguration
    private let logger = Logger(label: "com.rxlab.rxstorage.AuthenticationMiddleware")

    /// Track if a token refresh is in progress
    private var isRefreshing = false
    private var pendingRequests: [CheckedContinuation<Void, Error>] = []

    public init(
        tokenStorage: TokenStorageProtocol,
        configuration: RxAuthConfiguration
    ) {
        self.tokenStorage = tokenStorage
        self.configuration = configuration
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Inject Bearer token if available
        var modifiedRequest = request
        if let accessToken = tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }

        // Make request
        let (response, responseBody) = try await next(modifiedRequest, body, baseURL)

        // Only refresh on 401 response
        if response.status == .unauthorized {
            logger.info("Received 401, attempting token refresh", metadata: ["operationID": "\(operationID)"])

            // Check if refresh is possible
            guard tokenStorage.getRefreshToken() != nil else {
                logger.error("No refresh token available for 401 retry")
                await MainActor.run {
                    NotificationCenter.default.post(name: .rxAuthSessionExpired, object: nil)
                }
                return (response, responseBody)
            }

            do {
                try await ensureValidToken()

                // Retry with new token
                var retryRequest = request
                if let accessToken = tokenStorage.getAccessToken() {
                    retryRequest.headerFields[.authorization] = "Bearer \(accessToken)"
                }
                return try await next(retryRequest, body, baseURL)
            } catch {
                logger.error("Token refresh failed during 401 retry", metadata: ["error": "\(error)"])
                await MainActor.run {
                    NotificationCenter.default.post(name: .rxAuthSessionExpired, object: nil)
                }
                return (response, responseBody)
            }
        }

        return (response, responseBody)
    }

    // MARK: - Token Validation

    /// Ensure the access token is valid, refreshing if necessary
    private func ensureValidToken() async throws {
        // If already refreshing, wait for that refresh to complete
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append(continuation)
            }
        }

        // Double-check if still expired
        guard tokenStorage.isTokenExpired() else { return }

        guard tokenStorage.getRefreshToken() != nil else {
            logger.error("No refresh token available")
            throw AuthenticationError.noRefreshToken
        }

        // Start refreshing
        isRefreshing = true

        do {
            logger.info("Refreshing access token")
            try await performTokenRefresh()
            logger.info("Access token refreshed successfully")

            // Success - resume all waiting continuations
            let continuations = pendingRequests
            pendingRequests = []
            isRefreshing = false

            for continuation in continuations {
                continuation.resume()
            }
        } catch {
            // Failure - resume all waiting continuations with the error
            let continuations = pendingRequests
            pendingRequests = []
            isRefreshing = false

            for continuation in continuations {
                continuation.resume(throwing: error)
            }
            throw error
        }
    }

    // MARK: - Token Refresh

    /// Refresh access token using refresh token
    private func performTokenRefresh() async throws {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            throw AuthenticationError.noRefreshToken
        }

        guard let url = configuration.tokenURL else {
            throw AuthenticationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.clientID,
        ]

        request.httpBody =
            bodyParams
                .map {
                    "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                .joined(separator: "&")
                .data(using: .utf8)

        // Perform token refresh
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error(
                    "Token refresh failed",
                    metadata: [
                        "status": "\(httpResponse.statusCode)",
                        "response": "\(errorString.prefix(200))",
                    ]
                )
            }
            throw AuthenticationError.refreshFailed
        }

        // Decode token response
        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save new tokens
        try tokenStorage.saveAccessToken(tokenResponse.access_token)

        if let newRefreshToken = tokenResponse.refresh_token {
            try tokenStorage.saveRefreshToken(newRefreshToken)
        }

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        try tokenStorage.saveExpiresAt(expiresAt)
    }
}

// MARK: - Authentication Errors

public enum AuthenticationError: LocalizedError, Sendable {
    case noRefreshToken
    case invalidURL
    case invalidResponse
    case refreshFailed

    public var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidURL:
            return "Invalid authentication URL"
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .refreshFailed:
            return "Token refresh failed"
        }
    }
}
