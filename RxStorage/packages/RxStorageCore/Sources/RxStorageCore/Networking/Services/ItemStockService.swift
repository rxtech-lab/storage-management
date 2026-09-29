//
//  ItemStockService.swift
//  RxStorageCore
//
//  Item stock placement service: move units between parents and edit placements
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "ItemStockService")

// MARK: - Protocol

/// Protocol for item stock placement operations
public protocol ItemStockServiceProtocol: Sendable {
    func moveStock(itemId: String, _ request: MoveItemStockRequest) async throws -> MoveItemStockResponse
    func updateStock(id: String, _ request: UpdateItemStockRequest) async throws -> ItemStock
    func deleteStock(id: String) async throws
}

// MARK: - Implementation

/// Item stock placement service implementation using generated OpenAPI client
public struct ItemStockService: ItemStockServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func moveStock(itemId: String, _ request: MoveItemStockRequest) async throws -> MoveItemStockResponse {
        try await StorageAPIClient.shared.client.moveItemStock(.init(
            path: .init(id: itemId),
            body: .json(request)
        ))
    }

    @APICall(.ok)
    public func updateStock(id: String, _ request: UpdateItemStockRequest) async throws -> ItemStock {
        try await StorageAPIClient.shared.client.updateItemStock(.init(
            path: .init(id: id),
            body: .json(request)
        ))
    }

    public func deleteStock(id: String) async throws {
        let response = try await StorageAPIClient.shared.client.deleteItemStock(.init(path: .init(id: id)))

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            logger.error("Unexpected status deleting stock placement: \(statusCode)")
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
