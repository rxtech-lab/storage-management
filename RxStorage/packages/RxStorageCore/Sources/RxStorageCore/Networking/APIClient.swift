//
//  APIClient.swift
//  RxStorageCore
//
//  HTTP client with Bearer token injection and automatic token refresh
//

import Foundation
import Logging

/// HTTP client for API requests with automatic authentication
public actor APIClient {
    /// Shared singleton instance
    public static let shared = APIClient()

    private let session: URLSession
    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage
    private let logger = Logger(label: "com.rxlab.rxstorage.APIClient")

    /// Track if a token refresh is in progress
    private var isRefreshing = false
    private var pendingRequests: [CheckedContinuation<Void, Error>] = []

    public init(
        session: URLSession = .shared,
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) {
        self.session = session
        self.configuration = configuration
        self.tokenStorage = tokenStorage
    }

    // MARK: - Request Methods

    /// Perform GET request
    public func get<T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(
            endpoint, method: .get, bodyData: nil, responseType: responseType)
    }

    /// Perform GET request without requiring authentication (for public endpoints)
    /// This method will include Bearer token if available but won't fail if no token exists.
    /// Used by App Clips to access public items without requiring login.
    public func getPublic<T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await requestPublic(
            endpoint, method: .get, responseType: responseType)
    }

    /// Perform POST request
    public func post<B: Encodable & Sendable, T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        body: B,
        responseType: T.Type
    ) async throws -> T {
        // Encode body data before entering actor-isolated code
        let encoder = JSONEncoder()
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            print("🔴 [APIClient] Failed to encode body: \(error)")
            throw APIError.badRequest("Failed to encode request body: \(error.localizedDescription)")
        }
        return try await request(endpoint, method: .post, bodyData: bodyData, responseType: responseType)
    }

    /// Perform PUT request
    public func put<B: Encodable & Sendable, T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        body: B,
        responseType: T.Type
    ) async throws -> T {
        // Encode body data before entering actor-isolated code
        let encoder = JSONEncoder()
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            print("🔴 [APIClient] Failed to encode body: \(error)")
            throw APIError.badRequest("Failed to encode request body: \(error.localizedDescription)")
        }
        return try await request(endpoint, method: .put, bodyData: bodyData, responseType: responseType)
    }

    /// Perform DELETE request
    public func delete<T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(
            endpoint, method: .delete, bodyData: nil, responseType: responseType)
    }

    /// Perform DELETE request with no response body expected
    public func delete(_ endpoint: APIEndpoint) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await request(
            endpoint, method: .delete, bodyData: nil, responseType: EmptyResponse.self)
    }

    /// Perform GET request to an arbitrary URL (for QR code scanning / deep links)
    /// URLSession will automatically follow redirects
    public func getFromURL<T: Codable & Sendable>(
        _ url: URL,
        responseType: T.Type
    ) async throws -> T {
        // Check if token needs refresh
        if await tokenStorage.isTokenExpired() {
            try await ensureValidToken()
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Bearer token
        if let accessToken = await tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Perform request (URLSession follows redirects automatically)
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return try Self.decodeResponse(data: data, responseType: responseType, logger: logger)
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.badRequest(errorResponse.error)
                }
                throw APIError.badRequest("Client error")
            default:
                throw APIError.serverError("Server error")
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Core Request Method

    private func request<T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        bodyData: Data?,
        responseType: T.Type,
        isRetry: Bool = false
    ) async throws -> T {
        // Check if token needs refresh before making request
        if await tokenStorage.isTokenExpired() {
            try await ensureValidToken()
        }

        // Build URL
        guard var urlComponents = URLComponents(string: configuration.apiBaseURL) else {
            throw APIError.invalidURL
        }

        urlComponents.path = endpoint.path

        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Bearer token
        if let accessToken = await tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let bodyData = bodyData {
            request.httpBody = bodyData
            // Debug: log the JSON body being sent
            if let jsonString = String(data: bodyData, encoding: .utf8) {
                print("🔵 [APIClient] Request URL: \(url)")
                print("🔵 [APIClient] Request method: \(method.rawValue)")
                print("🔵 [APIClient] Request body (\(bodyData.count) bytes): \(jsonString)")
            }
        }

        // Perform request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                return try Self.decodeResponse(
                    data: data, responseType: responseType, logger: logger)

            case 401:
                // Unauthorized - try to refresh token and retry (once)
                if !isRetry {
                    logger.info(
                        "Received 401, attempting token refresh",
                        metadata: [
                            "endpoint": "\(endpoint.path)"
                        ])
                    do {
                        try await ensureValidToken()
                        // Retry the request with the new token
                        return try await self.request(
                            endpoint, method: method, bodyData: bodyData, responseType: responseType,
                            isRetry: true)
                    } catch {
                        logger.error(
                            "Token refresh failed during 401 retry",
                            metadata: [
                                "error": "\(error)"
                            ])
                        // Post notification for UI to handle logout
                        await MainActor.run {
                            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
                        }
                        throw APIError.refreshTokenError
                    }
                }
                // Already retried, give up
                await MainActor.run {
                    NotificationCenter.default.post(name: .authSessionExpired, object: nil)
                }
                throw APIError.unauthorized

            case 403:
                throw APIError.forbidden

            case 404:
                throw APIError.notFound

            case 400...499:
                // Client error - try to extract error message
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                {
                    throw APIError.badRequest(errorResponse.error)
                }
                throw APIError.badRequest("Client error")

            case 500...599:
                // Server error - try to extract error message
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.serverError("Server error")

            default:
                throw APIError.invalidResponse
            }

        } catch let error as APIError {
            logger.error(
                "API error: \(error.localizedDescription)",
                metadata: [
                    "endpoint": "\(endpoint.path)",
                    "method": "\(method.rawValue)",
                ])
            throw error
        } catch {
            logger.error(
                "Network error: \(error.localizedDescription)",
                metadata: [
                    "endpoint": "\(endpoint.path)",
                    "method": "\(method.rawValue)",
                    "error": "\(error)",
                ])
            throw APIError.networkError(error)
        }
    }

    // MARK: - Public Request Method (No Token Required)

    /// Request method for public endpoints that don't require authentication.
    /// Includes Bearer token if available but doesn't fail if no token exists.
    private func requestPublic<T: Codable & Sendable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        responseType: T.Type
    ) async throws -> T {
        // Build URL - same as regular request
        guard var urlComponents = URLComponents(string: configuration.apiBaseURL) else {
            throw APIError.invalidURL
        }

        urlComponents.path = endpoint.path

        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Bearer token IF available (but don't require it)
        if let accessToken = await tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Perform request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                return try Self.decodeResponse(
                    data: data, responseType: responseType, logger: logger)

            case 401:
                // For public endpoints, 401 means private item needs auth
                throw APIError.unauthorized

            case 403:
                // Forbidden - user authenticated but not whitelisted
                throw APIError.forbidden

            case 404:
                throw APIError.notFound

            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                {
                    throw APIError.badRequest(errorResponse.error)
                }
                throw APIError.badRequest("Client error")

            case 500...599:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.serverError("Server error")

            default:
                throw APIError.invalidResponse
            }

        } catch let error as APIError {
            logger.error(
                "API error: \(error.localizedDescription)",
                metadata: [
                    "endpoint": "\(endpoint.path)",
                    "method": "\(method.rawValue)",
                ])
            throw error
        } catch {
            logger.error(
                "Network error: \(error.localizedDescription)",
                metadata: [
                    "endpoint": "\(endpoint.path)",
                    "method": "\(method.rawValue)",
                    "error": "\(error)",
                ])
            throw APIError.networkError(error)
        }
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

        // Double-check if still expired (another request might have refreshed)
        guard await tokenStorage.isTokenExpired() else { return }

        guard await tokenStorage.getRefreshToken() != nil else {
            logger.error("No refresh token available")
            throw APIError.refreshTokenError
        }

        // Start refreshing
        isRefreshing = true

        do {
            logger.info("Refreshing access token")
            try await refreshAccessToken()
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

    // MARK: - Response Decoding

    /// Decode API response data into the expected type
    internal static func decodeResponse<T: Codable & Sendable>(
        data: Data, responseType: T.Type, logger: Logger
    ) throws -> T {
        let decoder = JSONDecoder.apiDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode raw data"
            logger.error(
                "Failed to decode response",
                metadata: [
                    "type": "\(T.self)",
                    "error": "\(error)",
                    "rawResponse": "\(rawResponse.prefix(500))",
                ])
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Token Refresh

    /// Refresh access token using refresh token
    public func refreshAccessToken() async throws {
        guard let refreshToken = await tokenStorage.getRefreshToken() else {
            logger.error("No refresh token available for refresh")
            throw APIError.refreshTokenError
        }

        // Build token refresh request
        var urlComponents = URLComponents(string: configuration.authIssuer)!
        urlComponents.path = "/api/oauth/token"

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.authClientID,
        ]

        request.httpBody =
            bodyParams
            .map {
                "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        // Perform token refresh
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                // Log the error response for debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.error(
                        "Token refresh failed",
                        metadata: [
                            "status": "\(httpResponse.statusCode)",
                            "response": "\(errorString.prefix(200))",
                        ])
                }
                throw APIError.refreshTokenError
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

        } catch let error as APIError {
            throw error
        } catch {
            logger.error("Token refresh network error: \(error.localizedDescription)")
            throw APIError.refreshTokenError
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the auth session has expired and user needs to re-authenticate
    public static let authSessionExpired = Notification.Name(
        "com.rxlab.rxstorage.authSessionExpired")
}
