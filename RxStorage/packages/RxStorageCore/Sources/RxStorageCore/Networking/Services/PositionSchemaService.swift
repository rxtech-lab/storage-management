//
//  PositionSchemaService.swift
//  RxStorageCore
//
//  Position schema service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "PositionSchemaService")

// MARK: - Protocol

/// Protocol for position schema service operations
public protocol PositionSchemaServiceProtocol: Sendable {
    func fetchPositionSchemas(filters: PositionSchemaFilters?) async throws -> [PositionSchema]
    func fetchPositionSchemasPaginated(filters: PositionSchemaFilters?) async throws -> PaginatedResponse<PositionSchema>
    func fetchPositionSchema(id: Int) async throws -> PositionSchema
    func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema
    func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema
    func deletePositionSchema(id: Int) async throws
}

// MARK: - Implementation

/// Position schema service implementation using generated OpenAPI client
public struct PositionSchemaService: PositionSchemaServiceProtocol {
    public init() {}

    public func fetchPositionSchemas(filters: PositionSchemaFilters?) async throws -> [PositionSchema] {
        let response = try await fetchPositionSchemasPaginated(filters: filters)
        return response.data
    }

    @APICall(.ok, transform: "transformPaginatedPositionSchemas")
    public func fetchPositionSchemasPaginated(filters: PositionSchemaFilters?) async throws -> PaginatedResponse<PositionSchema> {
        let direction = filters?.direction.flatMap { Operations.getPositionSchemas.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getPositionSchemas.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        try await StorageAPIClient.shared.client.getPositionSchemas(.init(query: query))
    }

    /// Transforms paginated position schemas response to PaginatedResponse
    private func transformPaginatedPositionSchemas(_ body: Components.Schemas.PaginatedPositionSchemasResponse) -> PaginatedResponse<PositionSchema> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok)
    public func fetchPositionSchema(id: Int) async throws -> PositionSchema {
        try await StorageAPIClient.shared.client.getPositionSchema(.init(path: .init(id: String(id))))
    }

    @APICall(.created)
    public func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema {
        try await StorageAPIClient.shared.client.createPositionSchema(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema {
        try await StorageAPIClient.shared.client.updatePositionSchema(.init(path: .init(id: String(id)), body: .json(request)))
    }

    public func deletePositionSchema(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deletePositionSchema(.init(path: .init(id: String(id))))

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
