//
//  PositionService.swift
//  RxStorageCore
//
//  API service for position operations
//

import Foundation

/// Protocol for position service operations
@MainActor
public protocol PositionServiceProtocol {
    func fetchItemPositions(itemId: Int) async throws -> [Position]
    func fetchPosition(id: Int) async throws -> Position
    func deletePosition(id: Int) async throws
}

/// Position service implementation
@MainActor
public class PositionService: PositionServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchItemPositions(itemId: Int) async throws -> [Position] {
        return try await apiClient.get(
            .listItemPositions(itemId: itemId),
            responseType: [Position].self
        )
    }

    public func fetchPosition(id: Int) async throws -> Position {
        return try await apiClient.get(
            .getPosition(id: id),
            responseType: Position.self
        )
    }

    public func deletePosition(id: Int) async throws {
        try await apiClient.delete(.deletePosition(id: id))
    }
}
