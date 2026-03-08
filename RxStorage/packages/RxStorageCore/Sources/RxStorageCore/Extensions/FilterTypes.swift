//
//  FilterTypes.swift
//  RxStorageCore
//
//  Filter and pagination helper types
//

import Foundation

// MARK: - Comparison Operator

/// Comparison operator for date filters
public enum ComparisonOperator: String, Sendable, CaseIterable, Identifiable {
    case gt
    case gte
    case lt
    case lte
    case eq

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .gt: "After"
        case .gte: "On or After"
        case .lt: "Before"
        case .lte: "On or Before"
        case .eq: "Exactly"
        }
    }
}

// MARK: - Item Filters

/// Filters for item queries
public struct ItemFilters: Sendable {
    public var categoryId: String?
    public var locationId: String?
    public var authorId: String?
    public var parentId: String?
    public var visibility: Visibility?
    public var search: String?
    public var sortBy: String?
    public var cursor: String?
    public var direction: PaginationDirection?
    public var limit: Int?
    public var tagIds: [String]?
    public var itemDateOp: ComparisonOperator?
    public var itemDateValue: Date?
    public var expiresAtOp: ComparisonOperator?
    public var expiresAtValue: Date?

    public init(
        categoryId: String? = nil,
        locationId: String? = nil,
        authorId: String? = nil,
        parentId: String? = nil,
        visibility: Visibility? = nil,
        search: String? = nil,
        sortBy: String? = nil,
        cursor: String? = nil,
        direction: PaginationDirection? = nil,
        limit: Int? = nil,
        tagIds: [String]? = nil,
        itemDateOp: ComparisonOperator? = nil,
        itemDateValue: Date? = nil,
        expiresAtOp: ComparisonOperator? = nil,
        expiresAtValue: Date? = nil
    ) {
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.visibility = visibility
        self.search = search
        self.sortBy = sortBy
        self.cursor = cursor
        self.direction = direction
        self.limit = limit
        self.tagIds = tagIds
        self.itemDateOp = itemDateOp
        self.itemDateValue = itemDateValue
        self.expiresAtOp = expiresAtOp
        self.expiresAtValue = expiresAtValue
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

/// Filters for tag queries
public struct TagFilters: Sendable {
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
    public let totalCount: Int

    public init(
        hasNextPage: Bool,
        hasPrevPage: Bool,
        nextCursor: String?,
        prevCursor: String?,
        totalCount: Int = 0
    ) {
        self.hasNextPage = hasNextPage
        self.hasPrevPage = hasPrevPage
        self.nextCursor = nextCursor
        self.prevCursor = prevCursor
        self.totalCount = totalCount
    }

    /// Create from generated PaginationInfo
    public init(from info: PaginationInfo) {
        hasNextPage = info.hasNextPage
        hasPrevPage = info.hasPrevPage
        nextCursor = info.nextCursor
        prevCursor = info.prevCursor
        totalCount = info.totalCount
    }
}
