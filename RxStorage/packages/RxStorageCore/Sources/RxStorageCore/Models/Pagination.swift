//
//  Pagination.swift
//  RxStorageCore
//
//  Pagination models for API responses
//

import Foundation

/// Pagination direction for cursor-based navigation
public enum PaginationDirection: String, Sendable, Codable {
    case next
    case prev
}

/// Pagination information from API response
public struct PaginationInfo: Codable, Sendable, Equatable {
    public let nextCursor: String?
    public let prevCursor: String?
    public let hasNextPage: Bool
    public let hasPrevPage: Bool

    public init(
        nextCursor: String? = nil,
        prevCursor: String? = nil,
        hasNextPage: Bool = false,
        hasPrevPage: Bool = false
    ) {
        self.nextCursor = nextCursor
        self.prevCursor = prevCursor
        self.hasNextPage = hasNextPage
        self.hasPrevPage = hasPrevPage
    }
}

/// Generic paginated response wrapper matching backend format
public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let data: [T]
    public let pagination: PaginationInfo

    public init(data: [T], pagination: PaginationInfo) {
        self.data = data
        self.pagination = pagination
    }
}

/// Default page size for pagination
public enum PaginationDefaults {
    public static let pageSize = 10
}
