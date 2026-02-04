//
//  ItemFilterViewModel.swift
//  RxStorageCore
//
//  View model for item filter sheet
//

import Foundation
import Observation

/// View model for item filter sheet
@Observable
@MainActor
public final class ItemFilterViewModel {
    // MARK: - Published Properties

    /// Available categories for filtering
    public private(set) var categories: [Category] = []

    /// Available locations for filtering
    public private(set) var locations: [Location] = []

    /// Available authors for filtering
    public private(set) var authors: [Author] = []

    /// Loading state
    public private(set) var isLoading = false

    /// Error state
    public private(set) var error: Error?

    // Current filter selections
    public var selectedCategoryId: Int?
    public var selectedLocationId: Int?
    public var selectedAuthorId: Int?
    public var selectedVisibility: Visibility?

    // MARK: - Dependencies

    private let categoryService: CategoryServiceProtocol
    private let locationService: LocationServiceProtocol
    private let authorService: AuthorServiceProtocol

    // MARK: - Initialization

    public init(
        initialFilters: ItemFilters = ItemFilters(),
        categoryService: CategoryServiceProtocol = CategoryService(),
        locationService: LocationServiceProtocol = LocationService(),
        authorService: AuthorServiceProtocol = AuthorService()
    ) {
        self.categoryService = categoryService
        self.locationService = locationService
        self.authorService = authorService

        // Initialize from existing filters
        selectedCategoryId = initialFilters.categoryId
        selectedLocationId = initialFilters.locationId
        selectedAuthorId = initialFilters.authorId
        selectedVisibility = initialFilters.visibility
    }

    // MARK: - Public Methods

    /// Load filter options (categories, locations, authors)
    public func loadFilterOptions() async {
        isLoading = true
        error = nil

        do {
            categories = try await categoryService.fetchCategories(filters: nil)
        } catch {
            print("Failed to load categories: \(error)")
        }

        do {
            locations = try await locationService.fetchLocations(filters: nil)
        } catch {
            print("Failed to load locations: \(error)")
        }

        do {
            authors = try await authorService.fetchAuthors(filters: nil)
        } catch {
            print("Failed to load authors: \(error)")
        }

        isLoading = false
    }

    /// Build ItemFilters from current selections
    public func buildFilters() -> ItemFilters {
        return ItemFilters(
            categoryId: selectedCategoryId,
            locationId: selectedLocationId,
            authorId: selectedAuthorId,
            visibility: selectedVisibility
        )
    }

    /// Check if any filters are active
    public var hasActiveFilters: Bool {
        selectedCategoryId != nil ||
            selectedLocationId != nil ||
            selectedAuthorId != nil ||
            selectedVisibility != nil
    }

    /// Clear all filter selections
    public func clearFilters() {
        selectedCategoryId = nil
        selectedLocationId = nil
        selectedAuthorId = nil
        selectedVisibility = nil
    }
}
