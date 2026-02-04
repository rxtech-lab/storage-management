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
    func fetchItemUsingUrl(url: String) async throws -> StorageItemDetail
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

    /// Fetch item directly using a full URL (not the generated OpenAPI client)
    /// This is used after QR code scanning to fetch from the resolved URL
    /// Always includes auth token if user is signed in
    /// - Parameter url: The full API URL to the item (e.g., "https://storage.rxlab.app/api/v1/items/123")
    /// - Returns: StorageItemDetail
    public func fetchItemUsingUrl(url: String) async throws -> StorageItemDetail {
        guard let requestUrl = URL(string: url) else {
            logger.error("Invalid URL for item fetch: \(url)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Always add auth token if user is signed in
        if let accessToken = await TokenStorage.shared.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        logger.info("Fetching item from URL: \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw APIError.invalidResponse
        }

        logger.debug("Item fetch response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            // Configure date decoding to handle ISO8601 with fractional seconds
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 with fractional seconds first
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                // Fall back to standard ISO8601
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }

            do {
                let item = try decoder.decode(StorageItemDetail.self, from: data)
                logger.info("Successfully fetched item: \(item.id)")
                return item
            } catch {
                logger.error("Failed to decode item response: \(error)")
                throw APIError.decodingError(error)
            }
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ItemErrorResponse.self, from: data) {
                throw APIError.badRequest(errorResponse.error)
            }
            throw APIError.badRequest("Invalid request")
        case 401:
            logger.warning("Item fetch unauthorized")
            throw APIError.unauthorized
        case 403:
            logger.warning("Item fetch forbidden")
            throw APIError.forbidden
        case 404:
            logger.warning("Item not found")
            throw APIError.notFound
        default:
            logger.error("Item fetch failed with status: \(httpResponse.statusCode)")
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
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

// MARK: - Helper Types

/// Simple error response structure for decoding API errors
private struct ItemErrorResponse: Decodable {
    let error: String
}
