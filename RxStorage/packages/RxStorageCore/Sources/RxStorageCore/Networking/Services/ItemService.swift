//
//  ItemService.swift
//  RxStorageCore
//
//  Item service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

let logger = Logger(label: "ItemService")

// MARK: - Protocol

/// Protocol for item service operations
public protocol ItemServiceProtocol: Sendable {
    func fetchItems(filters: ItemFilters?) async throws -> [StorageItem]
    func fetchItemsPaginated(filters: ItemFilters?) async throws -> PaginatedResponse<StorageItem>
    func fetchItem(id: Int) async throws -> StorageItemDetail
    func fetchPreviewItem(id: Int) async throws -> StorageItemDetail
    func createItem(_ request: NewItemRequest) async throws -> StorageItem
    func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem
    func deleteItem(id: Int) async throws
    func setParent(itemId: Int, parentId: Int?) async throws -> StorageItem
}

// MARK: - Implementation

/// Item service implementation using generated OpenAPI client
public struct ItemService: ItemServiceProtocol {
    public init() {}

    public func fetchItems(filters: ItemFilters?) async throws -> [StorageItem] {
        let response = try await fetchItemsPaginated(filters: filters)
        return response.data
    }

    public func fetchItemsPaginated(filters: ItemFilters?) async throws -> PaginatedResponse<StorageItem> {
        let client = StorageAPIClient.shared.client

        // Build query params - broken up to help compiler type-check
        let direction = filters?.direction.flatMap { Operations.getItems.Input.Query.directionPayload(rawValue: $0.rawValue) }
        // Convert visibility type from response schema to query schema (same raw values)
        let queryVisibility = filters?.visibility.flatMap { Operations.getItems.Input.Query.visibilityPayload(rawValue: $0.rawValue) }
        // Convert parentId Int? to OpenAPIValueContainer? (oneOf type: integer or "null" string)
        let parentIdContainer: OpenAPIValueContainer? = filters?.parentId.flatMap { id in
            try? OpenAPIValueContainer(unvalidatedValue: id)
        }
        let query = Operations.getItems.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search,
            categoryId: filters?.categoryId,
            locationId: filters?.locationId,
            authorId: filters?.authorId,
            parentId: parentIdContainer,
            visibility: queryVisibility
        )

        let response = try await client.getItems(.init(query: query))

        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            let pagination = PaginationState(from: body.pagination)
            return PaginatedResponse(data: body.data, pagination: pagination)
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func fetchItem(id: Int) async throws -> StorageItemDetail {
        let client = StorageAPIClient.shared.client

        let response = try await client.getItem(.init(path: .init(id: String(id))))

        // getItem endpoint: 200, 400, 403, 404, 500 (no 401 - public items accessible without auth)
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    /// Fetch item for preview (public access, optionally authenticated)
    /// Used by App Clips to load items - works for public items without auth
    @CatchDecodingErrors
    public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
        // Use optional auth client - will work for public items without auth
        // and for private items with valid auth
        let client = StorageAPIClient.shared.optionalAuthClient

        let response = try await client.getItem(.init(path: .init(id: String(id))))

        // getItem endpoint: 200, 400, 403, 404, 500 (no 401 - public items accessible without auth)
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        let client = StorageAPIClient.shared.client

        let response = try await client.createItem(.init(body: .json(request)))

        switch response {
        case .created(let createdResponse):
            return try createdResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem {
        let client = StorageAPIClient.shared.client

        let response = try await client.updateItem(.init(path: .init(id: String(id)), body: .json(request)))

        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func deleteItem(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deleteItem(.init(path: .init(id: String(id))))

        switch response {
        case .noContent:
            return
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func setParent(itemId: Int, parentId: Int?) async throws -> StorageItem {
        let client = StorageAPIClient.shared.client

        let request = SetParentRequest(parentId: parentId)
        let response = try await client.setItemParent(.init(path: .init(id: String(itemId)), body: .json(request)))

        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
