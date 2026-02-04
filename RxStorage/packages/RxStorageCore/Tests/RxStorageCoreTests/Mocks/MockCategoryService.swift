//
//  MockCategoryService.swift
//  RxStorageCoreTests
//
//  Mock category service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock category service for testing
@MainActor
public final class MockCategoryService: CategoryServiceProtocol {
    // MARK: - Properties

    public var fetchCategoriesResult: Result<[RxStorageCore.Category], Error> = .success([])
    public var fetchCategoriesPaginatedResult: Result<PaginatedResponse<RxStorageCore.Category>, Error>?
    public var fetchCategoryResult: Result<RxStorageCore.Category, Error>?
    public var createCategoryResult: Result<RxStorageCore.Category, Error>?
    public var updateCategoryResult: Result<RxStorageCore.Category, Error>?
    public var deleteCategoryResult: Result<Void, Error>?

    // Call tracking
    public var fetchCategoriesCalled = false
    public var fetchCategoriesPaginatedCalled = false
    public var fetchCategoryCalled = false
    public var lastFetchCategoryId: Int?
    public var createCategoryCalled = false
    public var updateCategoryCalled = false
    public var deleteCategoryCalled = false

    public var lastCreateCategoryRequest: NewCategoryRequest?
    public var lastUpdateCategoryId: Int?
    public var lastUpdateCategoryRequest: UpdateCategoryRequest?
    public var lastDeleteCategoryId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - CategoryServiceProtocol

    public func fetchCategories(filters _: CategoryFilters?) async throws -> [RxStorageCore.Category] {
        fetchCategoriesCalled = true
        switch fetchCategoriesResult {
        case let .success(categories):
            return categories
        case let .failure(error):
            throw error
        }
    }

    public func fetchCategoriesPaginated(filters: CategoryFilters?) async throws -> PaginatedResponse<RxStorageCore.Category> {
        fetchCategoriesPaginatedCalled = true
        if let result = fetchCategoriesPaginatedResult {
            switch result {
            case let .success(response):
                return response
            case let .failure(error):
                throw error
            }
        }
        // Default: wrap fetchCategoriesResult in paginated response
        let categories = try await fetchCategories(filters: filters)
        return PaginatedResponse(
            data: categories,
            pagination: PaginationState(hasNextPage: false, hasPrevPage: false, nextCursor: nil, prevCursor: nil)
        )
    }

    public func fetchCategory(id: Int) async throws -> RxStorageCore.Category {
        fetchCategoryCalled = true
        lastFetchCategoryId = id

        if let result = fetchCategoryResult {
            switch result {
            case let .success(category):
                return category
            case let .failure(error):
                throw error
            }
        }

        throw APIError.notFound
    }

    public func createCategory(_ request: NewCategoryRequest) async throws -> RxStorageCore.Category {
        createCategoryCalled = true
        lastCreateCategoryRequest = request

        if let result = createCategoryResult {
            switch result {
            case let .success(category):
                return category
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateCategory(id: Int, _ request: UpdateCategoryRequest) async throws -> RxStorageCore.Category {
        updateCategoryCalled = true
        lastUpdateCategoryId = id
        lastUpdateCategoryRequest = request

        if let result = updateCategoryResult {
            switch result {
            case let .success(category):
                return category
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteCategory(id: Int) async throws {
        deleteCategoryCalled = true
        lastDeleteCategoryId = id

        if let result = deleteCategoryResult {
            switch result {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }
    }
}
