//
//  PositionSchemaService.swift
//  RxStorageCore
//
//  Position schema service protocol and implementation using generated client
//

import Foundation

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

    public func fetchPositionSchemasPaginated(filters: PositionSchemaFilters?) async throws -> PaginatedResponse<PositionSchema> {
        let client = StorageAPIClient.shared.client

        let direction = filters?.direction.flatMap { Operations.getPositionSchemas.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getPositionSchemas.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        let response = try await client.getPositionSchemas(.init(query: query))

        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            let pagination = PaginationState(from: body.pagination)
            return PaginatedResponse(data: body.data, pagination: pagination)
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

    public func fetchPositionSchema(id: Int) async throws -> PositionSchema {
        let client = StorageAPIClient.shared.client

        let response = try await client.getPositionSchema(.init(path: .init(id: String(id))))

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

    public func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema {
        let client = StorageAPIClient.shared.client

        let response = try await client.createPositionSchema(.init(body: .json(request)))

        switch response {
        case .created(let createdResponse):
            return try createdResponse.body.json
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

    public func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema {
        let client = StorageAPIClient.shared.client

        let response = try await client.updatePositionSchema(.init(path: .init(id: String(id)), body: .json(request)))

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

    public func deletePositionSchema(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deletePositionSchema(.init(path: .init(id: String(id))))

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
