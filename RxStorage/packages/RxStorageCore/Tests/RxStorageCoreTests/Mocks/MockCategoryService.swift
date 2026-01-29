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
    public var fetchCategoryResult: Result<RxStorageCore.Category, Error>?
    public var createCategoryResult: Result<RxStorageCore.Category, Error>?
    public var updateCategoryResult: Result<RxStorageCore.Category, Error>?
    public var deleteCategoryResult: Result<Void, Error>?

    // Call tracking
    public var fetchCategoriesCalled = false
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

    public func fetchCategories() async throws -> [RxStorageCore.Category] {
        fetchCategoriesCalled = true
        switch fetchCategoriesResult {
        case .success(let categories):
            return categories
        case .failure(let error):
            throw error
        }
    }

    public func fetchCategory(id: Int) async throws -> RxStorageCore.Category {
        fetchCategoryCalled = true
        lastFetchCategoryId = id

        if let result = fetchCategoryResult {
            switch result {
            case .success(let category):
                return category
            case .failure(let error):
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
            case .success(let category):
                return category
            case .failure(let error):
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
            case .success(let category):
                return category
            case .failure(let error):
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
            case .failure(let error):
                throw error
            }
        }
    }
}
