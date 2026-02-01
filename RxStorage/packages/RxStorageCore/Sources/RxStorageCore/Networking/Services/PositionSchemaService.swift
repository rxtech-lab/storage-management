//
//  PositionSchemaService.swift
//  RxStorageCore
//
//  API service for position schema operations
//

import Foundation

/// Protocol for position schema service operations
@MainActor
public protocol PositionSchemaServiceProtocol {
    func fetchPositionSchemas(filters: PositionSchemaFilters?) async throws -> [PositionSchema]
    func fetchPositionSchemasPaginated(filters: PositionSchemaFilters?) async throws -> PaginatedResponse<PositionSchema>
    func fetchPositionSchema(id: Int) async throws -> PositionSchema
    func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema
    func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema
    func deletePositionSchema(id: Int) async throws
}

/// Position schema service implementation
@MainActor
public class PositionSchemaService: PositionSchemaServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchPositionSchemas(filters: PositionSchemaFilters? = nil) async throws -> [PositionSchema] {
        return try await apiClient.get(
            .listPositionSchemas(filters: filters),
            responseType: [PositionSchema].self
        )
    }

    public func fetchPositionSchemasPaginated(filters: PositionSchemaFilters? = nil) async throws -> PaginatedResponse<PositionSchema> {
        var paginatedFilters = filters ?? PositionSchemaFilters()
        if paginatedFilters.limit == nil {
            paginatedFilters.limit = PaginationDefaults.pageSize
        }

        return try await apiClient.get(
            .listPositionSchemas(filters: paginatedFilters),
            responseType: PaginatedResponse<PositionSchema>.self
        )
    }

    public func fetchPositionSchema(id: Int) async throws -> PositionSchema {
        return try await apiClient.get(
            .getPositionSchema(id: id),
            responseType: PositionSchema.self
        )
    }

    public func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema {
        return try await apiClient.post(
            .createPositionSchema,
            body: request,
            responseType: PositionSchema.self
        )
    }

    public func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema {
        return try await apiClient.put(
            .updatePositionSchema(id: id),
            body: request,
            responseType: PositionSchema.self
        )
    }

    public func deletePositionSchema(id: Int) async throws {
        try await apiClient.delete(.deletePositionSchema(id: id))
    }
}
