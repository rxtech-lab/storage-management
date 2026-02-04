//
//  StorageAPIClient.swift
//  RxStorageCore
//
//  Configured API client for Storage Management API using generated OpenAPI client
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Configured API client for Storage Management API
public final class StorageAPIClient: Sendable {
    /// Shared singleton instance with authentication
    public static let shared = StorageAPIClient()

    /// The generated OpenAPI client (requires authentication)
    public let client: Client

    /// Client with optional authentication (token added if available)
    public let optionalAuthClient: Client

    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage

    /// Create authenticated client
    public init(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage

        let joinedPath =
            configuration.apiBaseURL.hasSuffix("/api")
                ? configuration.apiBaseURL : configuration.apiBaseURL + "/api"
        let serverURL = URL(string: joinedPath)!

        // Configure date transcoder to handle ISO8601 dates with fractional seconds (.000Z)
        let clientConfiguration = Configuration(
            dateTranscoder: .iso8601WithFractionalSeconds
        )

        client = Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
                AuthenticationMiddleware(tokenStorage: tokenStorage, configuration: configuration),
            ]
        )

        optionalAuthClient = Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
                OptionalAuthMiddleware(tokenStorage: tokenStorage),
            ]
        )
    }

    /// Create client without authentication (for public endpoints like preview)
    /// Used by App Clips to access public items without requiring login.
    public static func publicClient(configuration: AppConfiguration = .shared) -> Client {
        let serverURL = URL(string: configuration.apiBaseURL)!
        let clientConfiguration = Configuration(
            dateTranscoder: .iso8601WithFractionalSeconds
        )
        return Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
            ]
        )
    }

    /// Create client with optional authentication
    /// Includes Bearer token if available but doesn't fail if no token exists.
    public static func optionalAuthClient(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) -> Client {
        let joinedPath =
            configuration.apiBaseURL.hasSuffix("/api")
                ? configuration.apiBaseURL : configuration.apiBaseURL + "/api"
        let serverURL = URL(string: joinedPath)!
        let clientConfiguration = Configuration(
            dateTranscoder: .iso8601WithFractionalSeconds
        )
        return Client(
            serverURL: serverURL,
            configuration: clientConfiguration,
            transport: URLSessionTransport(),
            middlewares: [
                LoggingMiddleware(),
                OptionalAuthMiddleware(tokenStorage: tokenStorage),
            ]
        )
    }
}

// MARK: - Optional Authentication Middleware

/// Middleware that adds Bearer token if available, but doesn't require it
public actor OptionalAuthMiddleware: ClientMiddleware {
    private let tokenStorage: TokenStorage

    public init(tokenStorage: TokenStorage = .shared) {
        self.tokenStorage = tokenStorage
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request

        // Add Bearer token IF available (but don't require it)
        if let accessToken = await tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }

        return try await next(modifiedRequest, body, baseURL)
    }
}
