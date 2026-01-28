//
//  APIError.swift
//  RxStorageCore
//
//  Typed errors for API operations
//

import Foundation

/// Errors that can occur during API operations
public enum APIError: LocalizedError {
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
        }
    }

    public var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .tokenExpired:
            return true
        default:
            return false
        }
    }
}

/// Standard API response wrapper
public struct APIResponse<T: Codable>: Codable {
    public let data: T?
    public let error: String?

    public init(data: T? = nil, error: String? = nil) {
        self.data = data
        self.error = error
    }
}

/// API error response
public struct APIErrorResponse: Codable {
    public let error: String

    public init(error: String) {
        self.error = error
    }
}
