//
//  PositionService.swift
//  RxStorageCore
//
//  Position service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "PositionService")

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

    @APICall(.ok)
    public func fetchItemPositions(itemId: Int) async throws -> [Position] {
        try await StorageAPIClient.shared.client.getItemPositions(.init(path: .init(id: String(itemId))))
    }

    public func deletePosition(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deletePosition(.init(path: .init(id: String(id))))

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
