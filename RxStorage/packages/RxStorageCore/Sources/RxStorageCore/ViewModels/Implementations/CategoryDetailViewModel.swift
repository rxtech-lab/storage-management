//
//  CategoryDetailViewModel.swift
//  RxStorage
//
//  Category detail view model for displaying category details
//

import Foundation
import Observation

/// Category detail view model
@Observable
@MainActor
public final class CategoryDetailViewModel {
    // MARK: - Properties

    public private(set) var category: RxStorageCore.Category?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let categoryService: CategoryServiceProtocol

    // MARK: - Initialization

    public init(categoryService: CategoryServiceProtocol? = nil) {
        self.categoryService = categoryService ?? CategoryService()
    }

    // MARK: - Public Methods

    public func fetchCategory(id: Int) async {
        isLoading = true
        error = nil

        do {
            category = try await categoryService.fetchCategory(id: id)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refresh() async {
        guard let categoryId = category?.id else { return }
        await fetchCategory(id: categoryId)
    }

    public func clearError() {
        error = nil
    }
}
