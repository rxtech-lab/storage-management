//
//  ItemDetailViewModelProtocol.swift
//  RxStorageCore
//
//  Protocol for item detail view model
//

import Foundation

/// Protocol for item detail view model operations
@MainActor
public protocol ItemDetailViewModelProtocol: AnyObject, Observable {
    /// Current item
    var item: StorageItem? { get }

    /// Child items (if hierarchical)
    var children: [StorageItem] { get }

    /// Contents attached to the item
    var contents: [Content] { get }

    /// Loading state
    var isLoading: Bool { get }

    /// Error state
    var error: Error? { get }

    /// Fetch item details
    func fetchItem(id: Int) async

    /// Fetch child items
    func fetchChildren() async

    /// Fetch item contents
    func fetchContents() async

    /// Refresh all data
    func refresh() async

    /// Add a child item by its ID (fetches fresh data to avoid memory issues)
    func addChildById(_ childId: Int) async throws

    /// Remove a child item by its ID
    func removeChildById(_ childId: Int) async throws
}
