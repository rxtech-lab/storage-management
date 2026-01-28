//
//  MockCategoryService.swift
//  RxStorageCoreTests
//
//  Mock category service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock category service for testing
public final class MockCategoryService: CategoryServiceProtocol {
    // MARK: - Properties

    public var fetchCategoriesResult: Result<[Category], Error> = .success([])
    public var createCategoryResult: Result<Category, Error>?
    public var updateCategoryResult: Result<Category, Error>?
    public var deleteCategoryResult: Result<Void, Error>?

    // Call tracking
    public var fetchCategoriesCalled = false
    public var createCategoryCalled = false
    public var updateCategoryCalled = false
    public var deleteCategoryCalled = false

    public var lastCreateCategoryRequest: NewCategoryRequest?
    public var lastUpdateCategoryId: Int?
    public var lastUpdateCategoryRequest: NewCategoryRequest?
    public var lastDeleteCategoryId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - CategoryServiceProtocol

    public func fetchCategories() async throws -> [Category] {
        fetchCategoriesCalled = true
        switch fetchCategoriesResult {
        case .success(let categories):
            return categories
        case .failure(let error):
            throw error
        }
    }

    public func createCategory(_ request: NewCategoryRequest) async throws -> Category {
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

    public func updateCategory(id: Int, _ request: NewCategoryRequest) async throws -> Category {
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
