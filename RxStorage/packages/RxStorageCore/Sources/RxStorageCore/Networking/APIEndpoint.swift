//
//  APIEndpoint.swift
//  RxStorageCore
//
//  API endpoint definitions
//

import Foundation

/// HTTP methods
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// API endpoints
public enum APIEndpoint: Sendable {
    // Items
    case listItems(filters: ItemFilters?)
    case getItem(id: Int)
    case createItem
    case updateItem(id: Int)
    case deleteItem(id: Int)
    case setItemParent(id: String)
    case getItemQR(id: Int)

    // Categories
    case listCategories(filters: CategoryFilters?)
    case getCategory(id: Int)
    case createCategory
    case updateCategory(id: Int)
    case deleteCategory(id: Int)

    // Locations
    case listLocations(filters: LocationFilters?)
    case getLocation(id: Int)
    case createLocation
    case updateLocation(id: Int)
    case deleteLocation(id: Int)

    // Authors
    case listAuthors(filters: AuthorFilters?)
    case getAuthor(id: Int)
    case createAuthor
    case updateAuthor(id: Int)
    case deleteAuthor(id: Int)

    // Position Schemas
    case listPositionSchemas(filters: PositionSchemaFilters?)
    case getPositionSchema(id: Int)
    case createPositionSchema
    case updatePositionSchema(id: Int)
    case deletePositionSchema(id: Int)

    // Positions
    case listItemPositions(itemId: Int)
    case getPosition(id: Int)
    case deletePosition(id: Int)

    // Content Schemas
    case listContentSchemas

    // Contents
    case listItemContents(itemId: Int)
    case createItemContent(itemId: Int)
    case getContent(id: Int)
    case updateContent(id: Int)
    case deleteContent(id: Int)

    // Preview
    case getItemPreview(id: Int)

    // Upload
    case getPresignedURL

    /// HTTP method for this endpoint
    public var method: HTTPMethod {
        switch self {
        case .listItems, .getItem, .getItemQR,
             .listCategories, .getCategory,
             .listLocations, .getLocation,
             .listAuthors, .getAuthor,
             .listPositionSchemas, .getPositionSchema,
             .listItemPositions, .getPosition,
             .listContentSchemas,
             .listItemContents, .getContent,
             .getItemPreview:
            return .get

        case .createItem, .createCategory, .createLocation, .createAuthor, .createPositionSchema,
             .createItemContent,
             .getPresignedURL:
            return .post

        case .updateItem, .updateCategory, .updateLocation, .updateAuthor, .updatePositionSchema,
             .updateContent,
             .setItemParent:
            return .put

        case .deleteItem, .deleteCategory, .deleteLocation, .deleteAuthor, .deletePositionSchema,
             .deletePosition, .deleteContent:
            return .delete
        }
    }

    /// URL path for this endpoint
    public var path: String {
        switch self {
        case .listItems:
            return "/api/v1/items"
        case .getItem(let id):
            return "/api/v1/items/\(id)"
        case .createItem:
            return "/api/v1/items"
        case .updateItem(let id):
            return "/api/v1/items/\(id)"
        case .deleteItem(let id):
            return "/api/v1/items/\(id)"
        case .setItemParent(let id):
            return "/api/v1/items/\(id)/parent"
        case .getItemQR(let id):
            return "/api/v1/items/\(id)/qr"

        case .listCategories:
            return "/api/v1/categories"
        case .getCategory(let id):
            return "/api/v1/categories/\(id)"
        case .createCategory:
            return "/api/v1/categories"
        case .updateCategory(let id):
            return "/api/v1/categories/\(id)"
        case .deleteCategory(let id):
            return "/api/v1/categories/\(id)"

        case .listLocations:
            return "/api/v1/locations"
        case .getLocation(let id):
            return "/api/v1/locations/\(id)"
        case .createLocation:
            return "/api/v1/locations"
        case .updateLocation(let id):
            return "/api/v1/locations/\(id)"
        case .deleteLocation(let id):
            return "/api/v1/locations/\(id)"

        case .listAuthors:
            return "/api/v1/authors"
        case .getAuthor(let id):
            return "/api/v1/authors/\(id)"
        case .createAuthor:
            return "/api/v1/authors"
        case .updateAuthor(let id):
            return "/api/v1/authors/\(id)"
        case .deleteAuthor(let id):
            return "/api/v1/authors/\(id)"

        case .listPositionSchemas:
            return "/api/v1/position-schemas"
        case .getPositionSchema(let id):
            return "/api/v1/position-schemas/\(id)"
        case .createPositionSchema:
            return "/api/v1/position-schemas"
        case .updatePositionSchema(let id):
            return "/api/v1/position-schemas/\(id)"
        case .deletePositionSchema(let id):
            return "/api/v1/position-schemas/\(id)"

        case .listItemPositions(let itemId):
            return "/api/v1/items/\(itemId)/positions"
        case .getPosition(let id):
            return "/api/v1/positions/\(id)"
        case .deletePosition(let id):
            return "/api/v1/positions/\(id)"

        case .listContentSchemas:
            return "/api/v1/content-schemas"

        case .listItemContents(let itemId):
            return "/api/v1/items/\(itemId)/contents"
        case .createItemContent(let itemId):
            return "/api/v1/items/\(itemId)/contents"
        case .getContent(let id):
            return "/api/v1/contents/\(id)"
        case .updateContent(let id):
            return "/api/v1/contents/\(id)"
        case .deleteContent(let id):
            return "/api/v1/contents/\(id)"

        case .getItemPreview(let id):
            return "/api/v1/preview/\(id)"

        case .getPresignedURL:
            return "/api/v1/upload/presigned"
        }
    }

    /// Query parameters for this endpoint
    public var queryItems: [URLQueryItem]? {
        switch self {
        case .listItems(let filters):
            return filters?.toQueryItems()
        case .listCategories(let filters):
            return filters?.toQueryItems()
        case .listLocations(let filters):
            return filters?.toQueryItems()
        case .listAuthors(let filters):
            return filters?.toQueryItems()
        case .listPositionSchemas(let filters):
            return filters?.toQueryItems()
        default:
            return nil
        }
    }
}

/// Item filters for list query
public struct ItemFilters: Sendable {
    public var categoryId: Int?
    public var locationId: Int?
    public var authorId: Int?
    public var parentId: Int??  // Optional<Optional<Int>> to distinguish null vs not set
    public var visibility: StorageItem.Visibility?
    public var search: String?

    public init(
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int?? = nil,
        visibility: StorageItem.Visibility? = nil,
        search: String? = nil
    ) {
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.visibility = visibility
        self.search = search
    }

    func toQueryItems() -> [URLQueryItem]? {
        var items: [URLQueryItem] = []

        if let categoryId = categoryId {
            items.append(URLQueryItem(name: "categoryId", value: String(categoryId)))
        }
        if let locationId = locationId {
            items.append(URLQueryItem(name: "locationId", value: String(locationId)))
        }
        if let authorId = authorId {
            items.append(URLQueryItem(name: "authorId", value: String(authorId)))
        }
        if let parentId = parentId {
            if let id = parentId {
                items.append(URLQueryItem(name: "parentId", value: String(id)))
            } else {
                items.append(URLQueryItem(name: "parentId", value: "null"))
            }
        }
        if let visibility = visibility {
            items.append(URLQueryItem(name: "visibility", value: visibility.rawValue))
        }
        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }

        return items.isEmpty ? nil : items
    }
}

/// Author filters for list query
public struct AuthorFilters: Sendable {
    public var search: String?
    public var limit: Int?

    public init(
        search: String? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.limit = limit
    }

    func toQueryItems() -> [URLQueryItem]? {
        var items: [URLQueryItem] = []

        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return items.isEmpty ? nil : items
    }
}

/// Category filters for list query
public struct CategoryFilters: Sendable {
    public var search: String?
    public var limit: Int?

    public init(
        search: String? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.limit = limit
    }

    func toQueryItems() -> [URLQueryItem]? {
        var items: [URLQueryItem] = []

        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return items.isEmpty ? nil : items
    }
}

/// Location filters for list query
public struct LocationFilters: Sendable {
    public var search: String?
    public var limit: Int?

    public init(
        search: String? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.limit = limit
    }

    func toQueryItems() -> [URLQueryItem]? {
        var items: [URLQueryItem] = []

        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return items.isEmpty ? nil : items
    }
}

/// Position schema filters for list query
public struct PositionSchemaFilters: Sendable {
    public var search: String?
    public var limit: Int?

    public init(
        search: String? = nil,
        limit: Int? = nil
    ) {
        self.search = search
        self.limit = limit
    }

    func toQueryItems() -> [URLQueryItem]? {
        var items: [URLQueryItem] = []

        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return items.isEmpty ? nil : items
    }
}
