//
//  CategoryService.swift
//  RxStorageCore
//
//  Category service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

fileprivate let logger = Logger(label: "CategoryService")

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

    @APICall(.ok, transform: "transformPaginatedCategories")
    public func fetchCategoriesPaginated(filters: CategoryFilters?) async throws -> PaginatedResponse<Category> {
        let direction = filters?.direction.flatMap { Operations.getCategories.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getCategories.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        try await StorageAPIClient.shared.client.getCategories(.init(query: query))
    }

    /// Transforms paginated categories response to PaginatedResponse
    private func transformPaginatedCategories(_ body: Components.Schemas.PaginatedCategoriesResponse) -> PaginatedResponse<Category> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok)
    public func fetchCategory(id: Int) async throws -> Category {
        try await StorageAPIClient.shared.client.getCategory(.init(path: .init(id: String(id))))
    }

    @APICall(.created)
    public func createCategory(_ request: NewCategoryRequest) async throws -> Category {
        try await StorageAPIClient.shared.client.createCategory(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category {
        try await StorageAPIClient.shared.client.updateCategory(.init(path: .init(id: String(id)), body: .json(request)))
    }

    public func deleteCategory(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deleteCategory(.init(path: .init(id: String(id))))

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
