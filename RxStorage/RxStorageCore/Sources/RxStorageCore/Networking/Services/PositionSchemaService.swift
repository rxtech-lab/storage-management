//
//  PositionSchemaService.swift
//  RxStorageCore
//
//  API service for position schema operations
//

import Foundation

/// Protocol for position schema service operations
public protocol PositionSchemaServiceProtocol {
    func fetchPositionSchemas() async throws -> [PositionSchema]
    func fetchPositionSchema(id: Int) async throws -> PositionSchema
    func createPositionSchema(_ request: NewPositionSchemaRequest) async throws -> PositionSchema
    func updatePositionSchema(id: Int, _ request: UpdatePositionSchemaRequest) async throws -> PositionSchema
    func deletePositionSchema(id: Int) async throws
}

/// Position schema service implementation
public class PositionSchemaService: PositionSchemaServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchPositionSchemas() async throws -> [PositionSchema] {
        return try await apiClient.get(
            .listPositionSchemas,
            responseType: [PositionSchema].self
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
