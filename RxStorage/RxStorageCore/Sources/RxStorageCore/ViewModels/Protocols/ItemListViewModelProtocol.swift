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

    /// Fetch items with current filters
    func fetchItems() async

    /// Refresh items
    func refreshItems() async

    /// Delete an item
    func deleteItem(_ item: StorageItem) async throws

    /// Clear filters
    func clearFilters()

    /// Apply filters
    func applyFilters(_ filters: ItemFilters)
}
