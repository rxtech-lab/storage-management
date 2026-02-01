//
//  APIError.swift
//  RxStorageCore
//
//  API error types for handling OpenAPI client errors
//

import Foundation

/// API errors that can occur during network requests
public enum APIError: LocalizedError, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case badRequest(String)
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL
    case invalidResponse
    case tokenExpired
    case refreshTokenError
    case unsupportedQRCode(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please log in."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .badRequest(let message):
            return message
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to process response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .refreshTokenError:
            return "Failed to refresh authentication. Please log in again."
        case .unsupportedQRCode(let url):
            return "This QR code points to an unsupported URL: \(url)"
        }
    }

    /// Check if error is an authentication error that requires re-login
    public var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .tokenExpired, .refreshTokenError:
            return true
        default:
            return false
        }
    }

    /// Check if this is a cancelled request (should be ignored in UI)
    public var isCancellation: Bool {
        if case .networkError(let error) = self {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
        }
        return false
    }
}

/// API error response structure from backend
public struct APIErrorResponse: Codable, Sendable {
    public let error: String
}

// MARK: - Pagination Defaults

/// Default pagination settings
public enum PaginationDefaults {
    /// Default page size for list requests
    public static let pageSize = 20

    /// Maximum page size allowed
    public static let maxPageSize = 100
}

// MARK: - Pagination Direction

/// Direction for cursor-based pagination
public enum PaginationDirection: String, Codable, Sendable {
    case next
    case prev
}
