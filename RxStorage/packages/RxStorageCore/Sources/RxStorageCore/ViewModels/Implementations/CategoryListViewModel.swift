//
//  CategoryListViewModel.swift
//  RxStorageCore
//
//  Category list view model implementation
//

import Foundation
import Observation

/// Category list view model implementation
@Observable
@MainActor
public final class CategoryListViewModel: CategoryListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var categories: [Category] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Dependencies

    private let categoryService: CategoryServiceProtocol

    // MARK: - Computed Properties

    public var filteredCategories: [Category] {
        guard !searchText.isEmpty else { return categories }
        return categories.filter { category in
            category.name.localizedCaseInsensitiveContains(searchText) ||
            (category.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Initialization

    public init(categoryService: CategoryServiceProtocol = CategoryService()) {
        self.categoryService = categoryService
    }

    // MARK: - Public Methods

    public func fetchCategories() async {
        isLoading = true
        error = nil

        do {
            categories = try await categoryService.fetchCategories()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshCategories() async {
        await fetchCategories()
    }

    public func deleteCategory(_ category: Category) async throws {
        try await categoryService.deleteCategory(id: category.id)

        // Remove from local list
        categories.removeAll { $0.id == category.id }
    }
}
