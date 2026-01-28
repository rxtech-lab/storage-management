//
//  APIEndpoint.swift
//  RxStorageCore
//
//  API endpoint definitions
//

import Foundation

/// HTTP methods
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// API endpoints
public enum APIEndpoint {
    // Items
    case listItems(filters: ItemFilters?)
    case getItem(id: Int)
    case createItem
    case updateItem(id: Int)
    case deleteItem(id: Int)
    case getItemChildren(id: Int)
    case getItemQR(id: Int)

    // Categories
    case listCategories
    case getCategory(id: Int)
    case createCategory
    case updateCategory(id: Int)
    case deleteCategory(id: Int)

    // Locations
    case listLocations
    case getLocation(id: Int)
    case createLocation
    case updateLocation(id: Int)
    case deleteLocation(id: Int)

    // Authors
    case listAuthors
    case getAuthor(id: Int)
    case createAuthor
    case updateAuthor(id: Int)
    case deleteAuthor(id: Int)

    // Position Schemas
    case listPositionSchemas
    case getPositionSchema(id: Int)
    case createPositionSchema
    case updatePositionSchema(id: Int)
    case deletePositionSchema(id: Int)

    // Preview
    case getItemPreview(id: Int)

    /// HTTP method for this endpoint
    public var method: HTTPMethod {
        switch self {
        case .listItems, .getItem, .getItemChildren, .getItemQR,
             .listCategories, .getCategory,
             .listLocations, .getLocation,
             .listAuthors, .getAuthor,
             .listPositionSchemas, .getPositionSchema,
             .getItemPreview:
            return .get

        case .createItem, .createCategory, .createLocation, .createAuthor, .createPositionSchema:
            return .post

        case .updateItem, .updateCategory, .updateLocation, .updateAuthor, .updatePositionSchema:
            return .put

        case .deleteItem, .deleteCategory, .deleteLocation, .deleteAuthor, .deletePositionSchema:
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
        case .getItemChildren(let id):
            return "/api/v1/items/\(id)/children"
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

        case .getItemPreview(let id):
            return "/api/v1/preview/\(id)"
        }
    }

    /// Query parameters for this endpoint
    public var queryItems: [URLQueryItem]? {
        switch self {
        case .listItems(let filters):
            return filters?.toQueryItems()
        default:
            return nil
        }
    }
}

/// Item filters for list query
public struct ItemFilters {
    public var categoryId: Int?
    public var locationId: Int?
    public var authorId: Int?
    public var parentId: Int??  // Optional<Optional<Int>> to distinguish null vs not set
    public var visibility: String?  // "public" or "private"
    public var search: String?

    public init(
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int?? = nil,
        visibility: String? = nil,
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
            items.append(URLQueryItem(name: "visibility", value: visibility))
        }
        if let search = search {
            items.append(URLQueryItem(name: "search", value: search))
        }

        return items.isEmpty ? nil : items
    }
}
