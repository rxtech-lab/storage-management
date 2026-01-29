//
//  APIError.swift
//  RxStorageCore
//
//  Typed errors for API operations
//

import Foundation

/// Errors that can occur during API operations
public enum APIError: LocalizedError, @unchecked Sendable {
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

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "You don't have access to this resource"
        case .notFound:
            return "Resource not found"
        case .badRequest(let message):
            return message
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError:
            return "Network connection error. Please check your internet connection"
        case .decodingError:
            return "Data format error. Please try again"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .tokenExpired:
            return "Your session has expired. Please sign in again"
        case .refreshTokenError:
            return "Unable to refresh your session. Please sign in again"
        }
    }

    public var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .tokenExpired, .refreshTokenError:
            return true
        default:
            return false
        }
    }

    /// Whether this error is a cancelled request (should be ignored silently)
    public var isCancellation: Bool {
        guard case .networkError(let underlyingError) = self else {
            return false
        }
        let nsError = underlyingError as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

/// API error response
public struct APIErrorResponse: Codable, Sendable {
    public let error: String

    public init(error: String) {
        self.error = error
    }
}
