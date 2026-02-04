//
//  ItemService.swift
//  RxStorageCore
//
//  Item service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "ItemService")

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

    @APICall(.ok, transform: "transformPaginatedItems")
    public func fetchItemsPaginated(filters: ItemFilters?) async throws -> PaginatedResponse<StorageItem> {
        // Build query params
        let direction = filters?.direction.flatMap { Operations.getItems.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let queryVisibility = filters?.visibility.flatMap { Operations.getItems.Input.Query.visibilityPayload(rawValue: $0.rawValue) }
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

        try await StorageAPIClient.shared.client.getItems(.init(query: query))
    }

    /// Transforms paginated items response to PaginatedResponse
    private func transformPaginatedItems(_ body: Components.Schemas.PaginatedItemsResponse) -> PaginatedResponse<StorageItem> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok)
    public func fetchItem(id: Int) async throws -> StorageItemDetail {
        try await StorageAPIClient.shared.client.getItem(.init(path: .init(id: String(id))))
    }

    /// Fetch item for preview (public access, optionally authenticated)
    /// Used by App Clips to load items - works for public items without auth
    @APICall(.ok)
    public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
        try await StorageAPIClient.shared.optionalAuthClient.getItem(.init(path: .init(id: String(id))))
    }

    @APICall(.created)
    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        try await StorageAPIClient.shared.client.createItem(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem {
        try await StorageAPIClient.shared.client.updateItem(.init(path: .init(id: String(id)), body: .json(request)))
    }

    @APICall(.noContent)
    public func deleteItem(id: Int) async throws {
        try await StorageAPIClient.shared.client.deleteItem(.init(path: .init(id: String(id))))
    }

    @APICall(.ok)
    public func setParent(itemId: Int, parentId: Int?) async throws -> StorageItem {
        let request = SetParentRequest(parentId: parentId)
        try await StorageAPIClient.shared.client.setItemParent(.init(path: .init(id: String(itemId)), body: .json(request)))
    }
}
