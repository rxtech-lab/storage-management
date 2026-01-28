//
//  ItemFormViewModel.swift
//  RxStorageCore
//
//  Item form view model implementation
//

import Foundation
import Observation

/// Item form view model implementation
@Observable
@MainActor
public final class ItemFormViewModel: ItemFormViewModelProtocol {
    // MARK: - Published Properties

    public let item: StorageItem?

    // Form fields
    public var title = ""
    public var description = ""
    public var selectedCategoryId: Int?
    public var selectedLocationId: Int?
    public var selectedAuthorId: Int?
    public var selectedParentId: Int?
    public var price = ""
    public var visibility: StorageItem.Visibility = .public
    public var imageURLs: [String] = []

    // Reference data
    public private(set) var categories: [Category] = []
    public private(set) var locations: [Location] = []
    public private(set) var authors: [Author] = []
    public private(set) var parentItems: [StorageItem] = []

    // State
    public private(set) var isLoading = false
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol
    private let categoryService: CategoryServiceProtocol
    private let locationService: LocationServiceProtocol
    private let authorService: AuthorServiceProtocol

    // MARK: - Initialization

    public init(
        item: StorageItem? = nil,
        itemService: ItemServiceProtocol = ItemService(),
        categoryService: CategoryServiceProtocol = CategoryService(),
        locationService: LocationServiceProtocol = LocationService(),
        authorService: AuthorServiceProtocol = AuthorService()
    ) {
        self.item = item
        self.itemService = itemService
        self.categoryService = categoryService
        self.locationService = locationService
        self.authorService = authorService

        // Populate form if editing
        if let item = item {
            populateForm(from: item)
        }
    }

    // MARK: - Public Methods

    public func loadReferenceData() async {
        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let categories = try await self.categoryService.fetchCategories()
                    await MainActor.run {
                        self.categories = categories
                    }
                } catch {
                    print("Failed to load categories: \(error)")
                }
            }

            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let locations = try await self.locationService.fetchLocations()
                    await MainActor.run {
                        self.locations = locations
                    }
                } catch {
                    print("Failed to load locations: \(error)")
                }
            }

            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let authors = try await self.authorService.fetchAuthors()
                    await MainActor.run {
                        self.authors = authors
                    }
                } catch {
                    print("Failed to load authors: \(error)")
                }
            }

            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    // Fetch potential parent items (exclude current item if editing)
                    let items = try await self.itemService.fetchItems(filters: nil)
                    await MainActor.run {
                        if let currentItemId = self.item?.id {
                            self.parentItems = items.filter { $0.id != currentItemId }
                        } else {
                            self.parentItems = items
                        }
                    }
                } catch {
                    print("Failed to load parent items: \(error)")
                }
            }
        }

        isLoading = false
    }

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate title
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["title"] = "Title is required"
        }

        // Validate price if provided
        if !price.isEmpty {
            if Double(price) == nil {
                validationErrors["price"] = "Invalid price format"
            }
        }

        return validationErrors.isEmpty
    }

    public func submit() async throws {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let priceValue = price.isEmpty ? nil : Double(price)

            let request = NewItemRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                categoryId: selectedCategoryId,
                locationId: selectedLocationId,
                authorId: selectedAuthorId,
                parentId: selectedParentId,
                price: priceValue,
                visibility: visibility,
                images: imageURLs
            )

            if let existingItem = item {
                // Update
                _ = try await itemService.updateItem(id: existingItem.id, request)
            } else {
                // Create
                _ = try await itemService.createItem(request)
            }

            isSubmitting = false
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Inline Entity Creation

    public func createCategory(name: String, description: String?) async throws -> Category {
        let request = NewCategoryRequest(name: name, description: description)
        let created = try await categoryService.createCategory(request)

        // Add to local list
        categories.append(created)

        return created
    }

    public func createLocation(title: String, latitude: Double, longitude: Double) async throws -> Location {
        let request = NewLocationRequest(title: title, latitude: latitude, longitude: longitude)
        let created = try await locationService.createLocation(request)

        // Add to local list
        locations.append(created)

        return created
    }

    public func createAuthor(name: String, bio: String?) async throws -> Author {
        let request = NewAuthorRequest(name: name, bio: bio)
        let created = try await authorService.createAuthor(request)

        // Add to local list
        authors.append(created)

        return created
    }

    // MARK: - Private Methods

    private func populateForm(from item: StorageItem) {
        title = item.title
        description = item.description ?? ""
        selectedCategoryId = item.categoryId
        selectedLocationId = item.locationId
        selectedAuthorId = item.authorId
        selectedParentId = item.parentId
        price = item.price ?? ""
        visibility = item.visibility
        imageURLs = item.images
    }
}

// MARK: - Form Error

public enum FormError: LocalizedError {
    case validationFailed

    public var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Please fix the validation errors"
        }
    }
}
