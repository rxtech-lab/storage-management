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
    public var selectedCategoryId: String?
    public var selectedLocationId: String?
    public var selectedAuthorId: String?
    public var selectedVisibility: Visibility?
    public var selectedTagIds: Set<String> = []
    public var itemDateOp: ComparisonOperator?
    public var itemDateValue: Date?
    public var expiresAtOp: ComparisonOperator?
    public var expiresAtValue: Date?

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
        selectedTagIds = Set(initialFilters.tagIds ?? [])
        itemDateOp = initialFilters.itemDateOp
        itemDateValue = initialFilters.itemDateValue
        expiresAtOp = initialFilters.expiresAtOp
        expiresAtValue = initialFilters.expiresAtValue
    }

    // MARK: - Public Methods

    /// Load filter options (categories, locations, authors, tags)
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
            visibility: selectedVisibility,
            tagIds: selectedTagIds.isEmpty ? nil : Array(selectedTagIds),
            itemDateOp: itemDateOp,
            itemDateValue: itemDateValue,
            expiresAtOp: expiresAtOp,
            expiresAtValue: expiresAtValue
        )
    }

    /// Check if any filters are active
    public var hasActiveFilters: Bool {
        selectedCategoryId != nil ||
            selectedLocationId != nil ||
            selectedAuthorId != nil ||
            selectedVisibility != nil ||
            !selectedTagIds.isEmpty ||
            itemDateOp != nil ||
            expiresAtOp != nil
    }

    /// Clear all filter selections
    public func clearFilters() {
        selectedCategoryId = nil
        selectedLocationId = nil
        selectedAuthorId = nil
        selectedVisibility = nil
        selectedTagIds = []
        itemDateOp = nil
        itemDateValue = nil
        expiresAtOp = nil
        expiresAtValue = nil
    }

    /// Toggle a tag selection
    public func toggleTag(_ tagId: String) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }
}
