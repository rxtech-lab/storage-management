//
//  MockItemStockService.swift
//  RxStorageCoreTests
//
//  Mock item stock placement service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock item stock placement service for testing
public final class MockItemStockService: ItemStockServiceProtocol, @unchecked Sendable {
    public var moveStockResult: Result<MoveItemStockResponse, Error> = .success(
        MoveItemStockResponse(stockId: nil, quantity: 0)
    )
    public var updateStockResult: Result<ItemStock, Error>?
    public var deleteStockResult: Result<Void, Error> = .success(())

    public var lastMoveItemId: String?
    public var lastMoveRequest: MoveItemStockRequest?
    public var lastUpdateStockId: String?
    public var lastUpdateRequest: UpdateItemStockRequest?
    public var lastDeleteStockId: String?

    public init() {}

    public func moveStock(itemId: String, _ request: MoveItemStockRequest) async throws -> MoveItemStockResponse {
        lastMoveItemId = itemId
        lastMoveRequest = request
        return try moveStockResult.get()
    }

    public func updateStock(id: String, _ request: UpdateItemStockRequest) async throws -> ItemStock {
        lastUpdateStockId = id
        lastUpdateRequest = request
        guard let updateStockResult else { throw APIError.notFound }
        return try updateStockResult.get()
    }

    public func deleteStock(id: String) async throws {
        lastDeleteStockId = id
        try deleteStockResult.get()
    }
}
