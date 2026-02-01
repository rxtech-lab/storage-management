//
//  AuthorService.swift
//  RxStorageCore
//
//  Author service protocol and implementation using generated client
//

import Foundation

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

    public func fetchAuthorsPaginated(filters: AuthorFilters?) async throws -> PaginatedResponse<Author> {
        let client = StorageAPIClient.shared.client

        let direction = filters?.direction.flatMap { Operations.getAuthors.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getAuthors.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        let response = try await client.getAuthors(.init(query: query))

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

    public func fetchAuthor(id: Int) async throws -> Author {
        let client = StorageAPIClient.shared.client

        let response = try await client.getAuthor(.init(path: .init(id: String(id))))

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

    public func createAuthor(_ request: NewAuthorRequest) async throws -> Author {
        let client = StorageAPIClient.shared.client

        let response = try await client.createAuthor(.init(body: .json(request)))

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

    public func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author {
        let client = StorageAPIClient.shared.client

        let response = try await client.updateAuthor(.init(path: .init(id: String(id)), body: .json(request)))

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

    public func deleteAuthor(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deleteAuthor(.init(path: .init(id: String(id))))

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
