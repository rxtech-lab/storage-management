//
//  CategoryDetailViewModel.swift
//  RxStorage
//
//  Category detail view model for displaying category details
//

import Foundation
import Observation
import RxStorageCore

/// Category detail view model
@Observable
@MainActor
final class CategoryDetailViewModel {
    // MARK: - Properties

    private(set) var category: RxStorageCore.Category?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Dependencies

    private let categoryService: CategoryServiceProtocol

    // MARK: - Initialization

    init(categoryService: CategoryServiceProtocol? = nil) {
        self.categoryService = categoryService ?? CategoryService()
    }

    // MARK: - Public Methods

    func fetchCategory(id: Int) async {
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

    func refresh() async {
        guard let categoryId = category?.id else { return }
        await fetchCategory(id: categoryId)
    }

    func clearError() {
        error = nil
    }
}
