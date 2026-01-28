//
//  ItemListViewModel.swift
//  RxStorageCore
//
//  Item list view model implementation
//

import Foundation
import Observation

/// Item list view model implementation
@Observable
@MainActor
public final class ItemListViewModel: ItemListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public var filters = ItemFilters()
    public var searchText = "" {
        didSet {
            // Update search filter when text changes
            if searchText.isEmpty {
                filters.search = nil
            } else {
                filters.search = searchText
            }
        }
    }

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol

    // MARK: - Initialization

    public init(itemService: ItemServiceProtocol = ItemService()) {
        self.itemService = itemService
    }

    // MARK: - Public Methods

    public func fetchItems() async {
        isLoading = true
        error = nil

        do {
            items = try await itemService.fetchItems(filters: filters.isEmpty ? nil : filters)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshItems() async {
        await fetchItems()
    }

    public func deleteItem(_ item: StorageItem) async throws {
        try await itemService.deleteItem(id: item.id)

        // Remove from local list
        items.removeAll { $0.id == item.id }
    }

    public func clearFilters() {
        filters = ItemFilters()
        searchText = ""
    }

    public func applyFilters(_ filters: ItemFilters) {
        self.filters = filters
        if let search = filters.search {
            searchText = search
        }
    }
}

// MARK: - ItemFilters Extension

extension ItemFilters {
    /// Check if filters are empty
    var isEmpty: Bool {
        categoryId == nil &&
        locationId == nil &&
        authorId == nil &&
        parentId == nil &&
        visibility == nil &&
        search == nil
    }
}
