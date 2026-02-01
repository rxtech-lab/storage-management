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

    /// Loading state
    var isLoading: Bool { get }

    /// Error state
    var error: Error? { get }

    /// Fetch item details (includes children)
    func fetchItem(id: Int) async

    /// Fetch item contents
    func fetchContents() async

    /// Refresh all data
    func refresh() async

    /// Add a child item by its ID (fetches fresh data to avoid memory issues)
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    func addChildById(_ childId: Int) async throws -> (parentId: Int, childId: Int)

    /// Remove a child item by its ID
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    func removeChildById(_ childId: Int) async throws -> (parentId: Int, childId: Int)

    /// Create a new content for this item
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    func createContent(type: ContentType, formData: [String: AnyCodable]) async throws -> (itemId: Int, contentId: Int)

    /// Delete an existing content
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    func deleteContent(id: Int) async throws -> (itemId: Int, contentId: Int)

    /// Update an existing content
    func updateContent(id: Int, type: ContentType, formData: [String: AnyCodable]) async throws
}
