//
//  ContentService.swift
//  RxStorageCore
//
//  API service for content operations
//

import Foundation

/// Protocol for content service operations
@MainActor
public protocol ContentServiceProtocol {
    func fetchItemContents(itemId: Int) async throws -> [Content]
    func fetchContent(id: Int) async throws -> Content
    func createContent(itemId: Int, _ request: ContentRequest) async throws -> Content
    func updateContent(id: Int, _ request: ContentRequest) async throws -> Content
    func deleteContent(id: Int) async throws
}

/// Content service implementation
@MainActor
public class ContentService: ContentServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchItemContents(itemId: Int) async throws -> [Content] {
        return try await apiClient.get(
            .listItemContents(itemId: itemId),
            responseType: [Content].self
        )
    }

    public func fetchContent(id: Int) async throws -> Content {
        return try await apiClient.get(
            .getContent(id: id),
            responseType: Content.self
        )
    }

    public func createContent(itemId: Int, _ request: ContentRequest) async throws -> Content {
        return try await apiClient.post(
            .createItemContent(itemId: itemId),
            body: request,
            responseType: Content.self
        )
    }

    public func updateContent(id: Int, _ request: ContentRequest) async throws -> Content {
        return try await apiClient.put(
            .updateContent(id: id),
            body: request,
            responseType: Content.self
        )
    }

    public func deleteContent(id: Int) async throws {
        try await apiClient.delete(.deleteContent(id: id))
    }
}
