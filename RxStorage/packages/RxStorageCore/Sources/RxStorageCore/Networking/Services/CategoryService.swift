//
//  CategoryService.swift
//  RxStorageCore
//
//  API service for category operations
//

import Foundation

/// Protocol for category service operations
@MainActor
public protocol CategoryServiceProtocol {
    func fetchCategories(filters: CategoryFilters?) async throws -> [Category]
    func fetchCategoriesPaginated(filters: CategoryFilters?) async throws -> PaginatedResponse<Category>
    func fetchCategory(id: Int) async throws -> Category
    func createCategory(_ request: NewCategoryRequest) async throws -> Category
    func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category
    func deleteCategory(id: Int) async throws
}

/// Category service implementation
@MainActor
public class CategoryService: CategoryServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchCategories(filters: CategoryFilters? = nil) async throws -> [Category] {
        return try await apiClient.get(
            .listCategories(filters: filters),
            responseType: [Category].self
        )
    }

    public func fetchCategoriesPaginated(filters: CategoryFilters? = nil) async throws -> PaginatedResponse<Category> {
        var paginatedFilters = filters ?? CategoryFilters()
        if paginatedFilters.limit == nil {
            paginatedFilters.limit = PaginationDefaults.pageSize
        }

        return try await apiClient.get(
            .listCategories(filters: paginatedFilters),
            responseType: PaginatedResponse<Category>.self
        )
    }

    public func fetchCategory(id: Int) async throws -> Category {
        return try await apiClient.get(
            .getCategory(id: id),
            responseType: Category.self
        )
    }

    public func createCategory(_ request: NewCategoryRequest) async throws -> Category {
        return try await apiClient.post(
            .createCategory,
            body: request,
            responseType: Category.self
        )
    }

    public func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category {
        return try await apiClient.put(
            .updateCategory(id: id),
            body: request,
            responseType: Category.self
        )
    }

    public func deleteCategory(id: Int) async throws {
        try await apiClient.delete(.deleteCategory(id: id))
    }
}
