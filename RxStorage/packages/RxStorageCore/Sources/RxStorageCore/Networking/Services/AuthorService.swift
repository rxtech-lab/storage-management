//
//  AuthorService.swift
//  RxStorageCore
//
//  Author service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

fileprivate let logger = Logger(label: "AuthorService")

// MARK: - Protocol

/// Protocol for author service operations
public protocol AuthorServiceProtocol: Sendable {
    func fetchAuthors(filters: AuthorFilters?) async throws -> [Author]
    func fetchAuthorsPaginated(filters: AuthorFilters?) async throws -> PaginatedResponse<Author>
    func fetchAuthor(id: Int) async throws -> Author
    func createAuthor(_ request: NewAuthorRequest) async throws -> Author
    func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author
    func deleteAuthor(id: Int) async throws
}

// MARK: - Implementation

/// Author service implementation using generated OpenAPI client
public struct AuthorService: AuthorServiceProtocol {
    public init() {}

    public func fetchAuthors(filters: AuthorFilters?) async throws -> [Author] {
        let response = try await fetchAuthorsPaginated(filters: filters)
        return response.data
    }

    @APICall(.ok, transform: "transformPaginatedAuthors")
    public func fetchAuthorsPaginated(filters: AuthorFilters?) async throws -> PaginatedResponse<Author> {
        let direction = filters?.direction.flatMap { Operations.getAuthors.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getAuthors.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        try await StorageAPIClient.shared.client.getAuthors(.init(query: query))
    }

    /// Transforms paginated authors response to PaginatedResponse
    private func transformPaginatedAuthors(_ body: Components.Schemas.PaginatedAuthorsResponse) -> PaginatedResponse<Author> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok)
    public func fetchAuthor(id: Int) async throws -> Author {
        try await StorageAPIClient.shared.client.getAuthor(.init(path: .init(id: String(id))))
    }

    @APICall(.created)
    public func createAuthor(_ request: NewAuthorRequest) async throws -> Author {
        try await StorageAPIClient.shared.client.createAuthor(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author {
        try await StorageAPIClient.shared.client.updateAuthor(.init(path: .init(id: String(id)), body: .json(request)))
    }

    public func deleteAuthor(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deleteAuthor(.init(path: .init(id: String(id))))

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
