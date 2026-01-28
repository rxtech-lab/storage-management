//
//  CategoryService.swift
//  RxStorageCore
//
//  API service for category operations
//

import Foundation

/// Protocol for category service operations
public protocol CategoryServiceProtocol {
    func fetchCategories() async throws -> [Category]
    func fetchCategory(id: Int) async throws -> Category
    func createCategory(_ request: NewCategoryRequest) async throws -> Category
    func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> Category
    func deleteCategory(id: Int) async throws
}

/// Category service implementation
public class CategoryService: CategoryServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchCategories() async throws -> [Category] {
        return try await apiClient.get(
            .listCategories,
            responseType: [Category].self
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
