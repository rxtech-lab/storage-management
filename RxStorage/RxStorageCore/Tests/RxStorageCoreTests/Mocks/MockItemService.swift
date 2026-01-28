//
//  MockItemService.swift
//  RxStorageCoreTests
//
//  Mock item service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock item service for testing
public final class MockItemService: ItemServiceProtocol {
    // MARK: - Properties

    public var fetchItemsResult: Result<[StorageItem], Error> = .success([])
    public var fetchItemResult: Result<StorageItem, Error>?
    public var fetchChildrenResult: Result<[StorageItem], Error> = .success([])
    public var createItemResult: Result<StorageItem, Error>?
    public var updateItemResult: Result<StorageItem, Error>?
    public var deleteItemResult: Result<Void, Error>?
    public var generateQRCodeResult: Result<QRCodeData, Error>?

    // Call tracking
    public var fetchItemsCalled = false
    public var fetchItemCalled = false
    public var fetchChildrenCalled = false
    public var createItemCalled = false
    public var updateItemCalled = false
    public var deleteItemCalled = false
    public var generateQRCodeCalled = false

    public var lastFetchItemId: Int?
    public var lastCreateItemRequest: NewItemRequest?
    public var lastUpdateItemId: Int?
    public var lastUpdateItemRequest: NewItemRequest?
    public var lastDeleteItemId: Int?
    public var lastGenerateQRCodeItemId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - ItemServiceProtocol

    public func fetchItems(filters: ItemFilters?) async throws -> [StorageItem] {
        fetchItemsCalled = true
        switch fetchItemsResult {
        case .success(let items):
            return items
        case .failure(let error):
            throw error
        }
    }

    public func fetchItem(id: Int) async throws -> StorageItem {
        fetchItemCalled = true
        lastFetchItemId = id

        if let result = fetchItemResult {
            switch result {
            case .success(let item):
                return item
            case .failure(let error):
                throw error
            }
        }

        throw APIError.notFound
    }

    public func fetchChildren(parentId: Int) async throws -> [StorageItem] {
        fetchChildrenCalled = true
        switch fetchChildrenResult {
        case .success(let items):
            return items
        case .failure(let error):
            throw error
        }
    }

    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        createItemCalled = true
        lastCreateItemRequest = request

        if let result = createItemResult {
            switch result {
            case .success(let item):
                return item
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateItem(id: Int, _ request: NewItemRequest) async throws -> StorageItem {
        updateItemCalled = true
        lastUpdateItemId = id
        lastUpdateItemRequest = request

        if let result = updateItemResult {
            switch result {
            case .success(let item):
                return item
            case .failure(let error):
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
            case .failure(let error):
                throw error
            }
        }
    }

    public func generateQRCode(itemId: Int) async throws -> QRCodeData {
        generateQRCodeCalled = true
        lastGenerateQRCodeItemId = itemId

        if let result = generateQRCodeResult {
            switch result {
            case .success(let qrData):
                return qrData
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }
}
