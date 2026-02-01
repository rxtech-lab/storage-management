//
//  PositionService.swift
//  RxStorageCore
//
//  Position service protocol and implementation using generated client
//

import Foundation

// MARK: - Protocol

/// Protocol for position service operations
public protocol PositionServiceProtocol: Sendable {
    func fetchItemPositions(itemId: Int) async throws -> [Position]
    func deletePosition(id: Int) async throws
}

// MARK: - Implementation

/// Position service implementation using generated OpenAPI client
public struct PositionService: PositionServiceProtocol {
    public init() {}

    public func fetchItemPositions(itemId: Int) async throws -> [Position] {
        let client = StorageAPIClient.shared.client

        let response = try await client.getItemPositions(.init(path: .init(id: String(itemId))))

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

    public func deletePosition(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deletePosition(.init(path: .init(id: String(id))))

        switch response {
        case .ok:
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
}
