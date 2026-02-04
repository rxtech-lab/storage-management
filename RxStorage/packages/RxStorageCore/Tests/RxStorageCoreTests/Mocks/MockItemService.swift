//
//  MockItemService.swift
//  RxStorageCoreTests
//
//  Mock item service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock item service for testing
@MainActor
public final class MockItemService: ItemServiceProtocol {
    // MARK: - Properties

    public var fetchItemsResult: Result<[StorageItem], Error> = .success([])
    public var fetchItemsPaginatedResult: Result<PaginatedResponse<StorageItem>, Error>?
    public var fetchItemResult: Result<StorageItemDetail, Error>?
    public var fetchPreviewItemResult: Result<StorageItemDetail, Error>?
    public var createItemResult: Result<StorageItem, Error>?
    public var updateItemResult: Result<StorageItem, Error>?
    public var setParentResult: Result<StorageItem, Error>?
    public var deleteItemResult: Result<Void, Error>?

    // Call tracking
    public var fetchItemsCalled = false
    public var fetchItemsPaginatedCalled = false
    public var fetchItemCalled = false
    public var fetchPreviewItemCalled = false
    public var createItemCalled = false
    public var updateItemCalled = false
    public var setParentCalled = false
    public var deleteItemCalled = false

    public var lastFetchItemId: Int?
    public var lastFetchPreviewItemId: Int?
    public var lastCreateItemRequest: NewItemRequest?
    public var lastUpdateItemId: Int?
    public var lastUpdateItemRequest: UpdateItemRequest?
    public var lastDeleteItemId: Int?
    public var lastSetParentItemId: Int?
    public var lastSetParentParentId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - ItemServiceProtocol

    public func fetchItems(filters _: ItemFilters?) async throws -> [StorageItem] {
        fetchItemsCalled = true
        switch fetchItemsResult {
        case let .success(items):
            return items
        case let .failure(error):
            throw error
        }
    }

    public func fetchItemsPaginated(filters: ItemFilters?) async throws -> PaginatedResponse<StorageItem> {
        fetchItemsPaginatedCalled = true
        if let result = fetchItemsPaginatedResult {
            switch result {
            case let .success(response):
                return response
            case let .failure(error):
                throw error
            }
        }
        // Default: wrap fetchItemsResult in paginated response
        let items = try await fetchItems(filters: filters)
        return PaginatedResponse(
            data: items,
            pagination: PaginationState(hasNextPage: false, hasPrevPage: false, nextCursor: nil, prevCursor: nil)
        )
    }

    public func fetchItem(id: Int) async throws -> StorageItemDetail {
        fetchItemCalled = true
        lastFetchItemId = id

        if let result = fetchItemResult {
            switch result {
            case let .success(item):
                return item
            case let .failure(error):
                throw error
            }
        }

        throw APIError.notFound
    }

    public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
        fetchPreviewItemCalled = true
        lastFetchPreviewItemId = id

        if let result = fetchPreviewItemResult {
            switch result {
            case let .success(item):
                return item
            case let .failure(error):
                throw error
            }
        }

        throw APIError.notFound
    }

    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        createItemCalled = true
        lastCreateItemRequest = request

        if let result = createItemResult {
            switch result {
            case let .success(item):
                return item
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem {
        updateItemCalled = true
        lastUpdateItemId = id
        lastUpdateItemRequest = request

        if let result = updateItemResult {
            switch result {
            case let .success(item):
                return item
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func setParent(itemId: Int, parentId: Int?) async throws -> StorageItem {
        setParentCalled = true
        lastSetParentItemId = itemId
        lastSetParentParentId = parentId

        if let result = setParentResult {
            switch result {
            case let .success(item):
                return item
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteItem(id: Int) async throws {
        deleteItemCalled = true
        lastDeleteItemId = id

        if let result = deleteItemResult {
            switch result {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }
    }
}
