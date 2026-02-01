//
//  ItemListViewModelProtocol.swift
//  RxStorageCore
//
//  Protocol for item list view model
//

import Foundation

/// Protocol for item list view model operations
@MainActor
public protocol ItemListViewModelProtocol: AnyObject, Observable {
    /// List of items
    var items: [StorageItem] { get }

    /// Loading state
    var isLoading: Bool { get }

    /// Error state
    var error: Error? { get }

    /// Current filters
    var filters: ItemFilters { get set }

    /// Search text
    var searchText: String { get set }

    // MARK: - Pagination Properties

    /// Whether more items are being loaded
    var isLoadingMore: Bool { get }

    /// Whether there are more items to load
    var hasNextPage: Bool { get }

    /// Fetch items with current filters
    func fetchItems() async

    /// Load more items (pagination)
    func loadMoreItems() async

    /// Refresh items
    func refreshItems() async

    /// Delete an item
    func deleteItem(_ item: StorageItem) async throws

    /// Clear filters
    func clearFilters()

    /// Apply filters
    func applyFilters(_ filters: ItemFilters)

    /// Clear error state
    func clearError()
}
