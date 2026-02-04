//
//  FilterTypes.swift
//  RxStorageCore
//
//  Filter and pagination helper types
//

import Foundation

// MARK: - Item Filters

/// Filters for item queries
public struct ItemFilters: Sendable {
    public var categoryId: Int?
    public var locationId: Int?
    public var authorId: Int?
    public var parentId: Int?
    public var visibility: Visibility?
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int? = nil,
        visibility: Visibility? = nil,
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.visibility = visibility
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

// MARK: - Entity Filters

/// Filters for category queries
public struct CategoryFilters: Sendable {
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

/// Filters for location queries
public struct LocationFilters: Sendable {
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

/// Filters for author queries
public struct AuthorFilters: Sendable {
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

/// Filters for position schema queries
public struct PositionSchemaFilters: Sendable {
    public var search: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?

    public init(
        search: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
    }
}

// MARK: - Paginated Response

/// Generic paginated response wrapper
public struct PaginatedResponse<T: Sendable>: Sendable {
    public let data: [T]
    public let pagination: PaginationState

    public init(data: [T], pagination: PaginationState) {
        self.data = data
        self.pagination = pagination
    }
}

/// Pagination state for UI
public struct PaginationState: Sendable {
    public let hasNextPage: Bool
    public let hasPrevPage: Bool
    public let nextCursor: String?
    public let prevCursor: String?

    public init(
        hasNextPage: Bool,
        hasPrevPage: Bool,
        nextCursor: String?,
        prevCursor: String?
    ) {
        self.hasNextPage = hasNextPage
        self.hasPrevPage = hasPrevPage
        self.nextCursor = nextCursor
        self.prevCursor = prevCursor
    }

    /// Create from generated PaginationInfo
    public init(from info: PaginationInfo) {
        hasNextPage = info.hasNextPage
        hasPrevPage = info.hasPrevPage
        nextCursor = info.nextCursor
        prevCursor = info.prevCursor
    }
}
