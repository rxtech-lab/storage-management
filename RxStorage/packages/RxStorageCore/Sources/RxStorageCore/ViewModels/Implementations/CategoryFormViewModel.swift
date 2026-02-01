//
//  CategoryFormViewModel.swift
//  RxStorageCore
//
//  Category form view model implementation
//

import Foundation
import Observation

/// Category form view model implementation
@Observable
@MainActor
public final class CategoryFormViewModel: CategoryFormViewModelProtocol {
    // MARK: - Published Properties

    public let category: Category?

    // Form fields
    public var name = ""
    public var description = ""

    // State
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let categoryService: CategoryServiceProtocol
    private let eventViewModel: EventViewModel?

    // MARK: - Initialization

    public init(
        category: Category? = nil,
        categoryService: CategoryServiceProtocol = CategoryService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.category = category
        self.categoryService = categoryService
        self.eventViewModel = eventViewModel

        // Populate form if editing
        if let category = category {
            populateForm(from: category)
        }
    }

    // MARK: - Public Methods

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["name"] = "Name is required"
        }

        return validationErrors.isEmpty
    }

    @discardableResult
    public func submit() async throws -> Category {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let result: Category
            if let existingCategory = category {
                // Update - use UpdateCategoryRequest
                let updateRequest = UpdateCategoryRequest(
                    name: name,
                    description: description.isEmpty ? nil : description
                )
                result = try await categoryService.updateCategory(id: existingCategory.id, updateRequest)
                eventViewModel?.emit(.categoryUpdated(id: result.id))
            } else {
                // Create - use NewCategoryRequest
                let createRequest = NewCategoryRequest(
                    name: name,
                    description: description.isEmpty ? nil : description
                )
                result = try await categoryService.createCategory(createRequest)
                eventViewModel?.emit(.categoryCreated(id: result.id))
            }

            isSubmitting = false
            return result
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Private Methods

    private func populateForm(from category: Category) {
        name = category.name
        description = category.description ?? ""
    }
}
