//
//  StockHistoryService.swift
//  RxStorageCore
//
//  Stock history service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "StockHistoryService")

// MARK: - Protocol

/// Protocol for stock history service operations
public protocol StockHistoryServiceProtocol: Sendable {
    func fetchItemStockHistory(itemId: String) async throws -> [StockHistory]
    func createStockHistory(itemId: String, _ request: NewStockHistoryRequest) async throws -> StockHistory
    func deleteStockHistory(id: String) async throws
}

// MARK: - Implementation

/// Stock history service implementation using generated OpenAPI client
public struct StockHistoryService: StockHistoryServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func fetchItemStockHistory(itemId: String) async throws -> [StockHistory] {
        try await StorageAPIClient.shared.client.getItemStockHistory(.init(path: .init(id: itemId)))
    }

    @APICall(.created)
    public func createStockHistory(itemId: String, _ request: NewStockHistoryRequest) async throws -> StockHistory {
        try await StorageAPIClient.shared.client.createItemStockHistory(.init(
            path: .init(id: itemId),
            body: .json(request)
        ))
    }

    public func deleteStockHistory(id: String) async throws {
        let response = try await StorageAPIClient.shared.client.deleteStockHistory(.init(path: .init(id: id)))

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
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
