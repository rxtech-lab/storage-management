//
//  ContentSchemaService.swift
//  RxStorageCore
//
//  API service for content schema operations
//

import Foundation

/// Protocol for content schema service operations
@MainActor
public protocol ContentSchemaServiceProtocol {
    func fetchContentSchemas() async throws -> [ContentSchema]
}

/// Content schema service implementation
@MainActor
public class ContentSchemaService: ContentSchemaServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchContentSchemas() async throws -> [ContentSchema] {
        return try await apiClient.get(
            .listContentSchemas,
            responseType: [ContentSchema].self
        )
    }
}
