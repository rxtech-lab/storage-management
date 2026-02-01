//
//  CategoryService.swift
//  RxStorageCore
//
//  Category service protocol and implementation using generated client
//

import Foundation

// MARK: - Protocol

/// Protocol for category service operations
public protocol CategoryServiceProtocol: Sendable {
    func fetchCategories(filters: CategoryFilters?) async throws -> [Category]
    func fetchCategoriesPaginated(filters: CategoryFilters?) async throws -> PaginatedResponse<Category>
    func fetchCategory(id: Int) async throws -> Category
    func createCategory(_ request: NewCategoryRequest) async throws -> Category
    func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category
    func deleteCategory(id: Int) async throws
}

// MARK: - Implementation

/// Category service implementation using generated OpenAPI client
public struct CategoryService: CategoryServiceProtocol {
    public init() {}

    public func fetchCategories(filters: CategoryFilters?) async throws -> [Category] {
        let response = try await fetchCategoriesPaginated(filters: filters)
        return response.data
    }

    public func fetchCategoriesPaginated(filters: CategoryFilters?) async throws -> PaginatedResponse<Category> {
        let client = StorageAPIClient.shared.client

        let direction = filters?.direction.flatMap { Operations.getCategories.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getCategories.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        let response = try await client.getCategories(.init(query: query))

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

    public func fetchCategory(id: Int) async throws -> Category {
        let client = StorageAPIClient.shared.client

        let response = try await client.getCategory(.init(path: .init(id: String(id))))

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

    public func createCategory(_ request: NewCategoryRequest) async throws -> Category {
        let client = StorageAPIClient.shared.client

        let response = try await client.createCategory(.init(body: .json(request)))

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

    public func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category {
        let client = StorageAPIClient.shared.client

        let response = try await client.updateCategory(.init(path: .init(id: String(id)), body: .json(request)))

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

    public func deleteCategory(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deleteCategory(.init(path: .init(id: String(id))))

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
