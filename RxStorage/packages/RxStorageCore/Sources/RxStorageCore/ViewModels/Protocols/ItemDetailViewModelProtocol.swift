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
    /// Current item (detail view with children and contents)
    var item: StorageItemDetail? { get }

    /// Child items (if hierarchical)
    var children: [StorageItem] { get }

    /// Contents attached to the item
    var contents: [Content] { get }

    /// Stock history entries
    var stockHistory: [StockHistoryRef] { get }

    /// Computed current stock quantity
    var quantity: Int { get }

    /// Loading state
    var isLoading: Bool { get }

    /// Error state
    var error: Error? { get }

    /// Fetch item details (includes children)
    func fetchItem(id: String) async

    /// Fetch item contents
    func fetchContents() async

    /// Refresh all data
    func refresh() async

    /// Add a child item by its ID (fetches fresh data to avoid memory issues)
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    func addChildById(_ childId: String) async throws -> (parentId: String, childId: String)

    /// Remove a child item by its ID
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    func removeChildById(_ childId: String) async throws -> (parentId: String, childId: String)

    /// Create a new content for this item
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    func createContent(type: ContentType, formData: [String: AnyCodable]) async throws -> (itemId: String, contentId: String)

    /// Delete an existing content
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    func deleteContent(id: String) async throws -> (itemId: String, contentId: String)

    /// Update an existing content
    func updateContent(id: String, type: ContentType, formData: [String: AnyCodable]) async throws

    /// Add a stock history entry
    /// Returns the created stock history entry
    @discardableResult
    func addStockEntry(quantity: Int, note: String?) async throws -> StockHistory

    /// Delete a stock history entry
    func deleteStockEntry(id: String) async throws
}
