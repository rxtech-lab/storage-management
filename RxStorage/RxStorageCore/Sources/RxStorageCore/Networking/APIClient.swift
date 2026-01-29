//
//  APIClient.swift
//  RxStorageCore
//
//  HTTP client with Bearer token injection and automatic token refresh
//

import Foundation
import Logging

/// HTTP client for API requests with automatic authentication
public class APIClient {
    /// Shared singleton instance
    public static let shared = APIClient()

    private let session: URLSession
    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage
    private let logger = Logger(label: "com.rxlab.rxstorage.APIClient")

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
    public func get<T: Codable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, method: .get, body: nil as String?, responseType: responseType)
    }

    /// Perform POST request
    public func post<B: Encodable, T: Codable>(
        _ endpoint: APIEndpoint,
        body: B,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, method: .post, body: body, responseType: responseType)
    }

    /// Perform PUT request
    public func put<B: Encodable, T: Codable>(
        _ endpoint: APIEndpoint,
        body: B,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, method: .put, body: body, responseType: responseType)
    }

    /// Perform DELETE request
    public func delete<T: Codable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, method: .delete, body: nil as String?, responseType: responseType)
    }

    /// Perform DELETE request with no response body expected
    public func delete(_ endpoint: APIEndpoint) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await request(endpoint, method: .delete, body: nil as String?, responseType: EmptyResponse.self)
    }

    // MARK: - Core Request Method

    private func request<B: Encodable, T: Codable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        body: B?,
        responseType: T.Type
    ) async throws -> T {
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
        if let accessToken = tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
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
                return try decodeResponse(data: data, responseType: responseType)

            case 401:
                // Unauthorized - try to refresh token and retry
                if tokenStorage.isTokenExpired() {
                    throw APIError.tokenExpired
                }
                throw APIError.unauthorized

            case 403:
                throw APIError.forbidden

            case 404:
                throw APIError.notFound

            case 400...499:
                // Client error - try to extract error message
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.badRequest(errorResponse.error)
                }
                throw APIError.badRequest("Client error")

            case 500...599:
                // Server error - try to extract error message
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.serverError("Server error")

            default:
                throw APIError.invalidResponse
            }

        } catch let error as APIError {
            logger.error("API error: \(error.localizedDescription)", metadata: [
                "endpoint": "\(endpoint.path)",
                "method": "\(method.rawValue)"
            ])
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription)", metadata: [
                "endpoint": "\(endpoint.path)",
                "method": "\(method.rawValue)",
                "error": "\(error)"
            ])
            throw APIError.networkError(error)
        }
    }

    // MARK: - Response Decoding

    private func decodeResponse<T: Codable>(data: Data, responseType: T.Type) throws -> T {
        do {
            // Try to decode as APIResponse wrapper first
            if let wrappedResponse = try? JSONDecoder().decode(APIResponse<T>.self, from: data) {
                if let data = wrappedResponse.data {
                    return data
                } else if let error = wrappedResponse.error {
                    throw APIError.serverError(error)
                } else {
                    throw APIError.invalidResponse
                }
            }

            // If not wrapped, try direct decoding
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode raw data"
            logger.error("Failed to decode response", metadata: [
                "type": "\(T.self)",
                "error": "\(error)",
                "rawResponse": "\(rawResponse.prefix(500))"
            ])
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Token Refresh

    /// Refresh access token using refresh token
    public func refreshAccessToken() async throws {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            throw APIError.tokenExpired
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
            "client_id": configuration.authClientID
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Perform token refresh
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.tokenExpired
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
