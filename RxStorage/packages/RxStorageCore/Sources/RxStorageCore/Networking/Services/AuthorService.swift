//
//  AuthorService.swift
//  RxStorageCore
//
//  API service for author operations
//

import Foundation

/// Protocol for author service operations
@MainActor
public protocol AuthorServiceProtocol {
    func fetchAuthors(filters: AuthorFilters?) async throws -> [Author]
    func fetchAuthor(id: Int) async throws -> Author
    func createAuthor(_ request: NewAuthorRequest) async throws -> Author
    func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author
    func deleteAuthor(id: Int) async throws
}

/// Author service implementation
@MainActor
public class AuthorService: AuthorServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchAuthors(filters: AuthorFilters? = nil) async throws -> [Author] {
        return try await apiClient.get(
            .listAuthors(filters: filters),
            responseType: [Author].self
        )
    }

    public func fetchAuthor(id: Int) async throws -> Author {
        return try await apiClient.get(
            .getAuthor(id: id),
            responseType: Author.self
        )
    }

    public func createAuthor(_ request: NewAuthorRequest) async throws -> Author {
        return try await apiClient.post(
            .createAuthor,
            body: request,
            responseType: Author.self
        )
    }

    public func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author {
        return try await apiClient.put(
            .updateAuthor(id: id),
            body: request,
            responseType: Author.self
        )
    }

    public func deleteAuthor(id: Int) async throws {
        try await apiClient.delete(.deleteAuthor(id: id))
    }
}
