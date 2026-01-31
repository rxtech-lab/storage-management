//
//  ItemDetailViewModel.swift
//  RxStorageCore
//
//  Item detail view model implementation
//

import Foundation
import Observation

/// Item detail view model implementation
@Observable
@MainActor
public final class ItemDetailViewModel: ItemDetailViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var item: StorageItem?
    public private(set) var children: [StorageItem] = []
    public private(set) var contents: [Content] = []
    public var contentSchemas: [ContentSchema] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol
    private let contentService: ContentServiceProtocol
    private let contentSchemaService: ContentSchemaServiceProtocol

    // MARK: - Initialization

    public init(
        itemService: ItemServiceProtocol = ItemService(),
        contentService: ContentServiceProtocol = ContentService(),
        contentSchemaService: ContentSchemaServiceProtocol = ContentSchemaService()
    ) {
        self.itemService = itemService
        self.contentService = contentService
        self.contentSchemaService = contentSchemaService
    }

    // MARK: - Public Methods

    public func fetchItem(id: Int) async {
        isLoading = true
        error = nil

        do {
            item = try await itemService.fetchItem(id: id)
            isLoading = false

            // Use children from item response
            children = item?.children ?? []

            // Use contents from item response
            contents = item?.contents ?? []
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func fetchContents() async {
        guard let itemId = item?.id else { return }

        do {
            contents = try await contentService.fetchItemContents(itemId: itemId)
        } catch {
            // Don't set main error for contents fetch failure
            print("Failed to fetch contents: \(error)")
        }
    }

    public func fetchContentSchemas() async {
        do {
            contentSchemas = try await contentSchemaService.fetchContentSchemas()
        } catch {
            print("Failed to fetch content schemas: \(error)")
        }
    }

    public func refresh() async {
        guard let itemId = item?.id else { return }
        await fetchItem(id: itemId)
    }

    // MARK: - Child Management

    /// Add a child item by its ID - fetches fresh data to avoid memory issues
    public func addChildById(_ childId: Int) async throws {
        guard let currentItemId = item?.id else { return }

        // Fetch the item fresh from API to avoid memory issues with passed objects
        let childItem = try await itemService.fetchItem(id: childId)

        // Create update request with new parentId
        let request = UpdateItemRequest(
            title: childItem.title,
            description: childItem.description,
            categoryId: childItem.categoryId,
            locationId: childItem.locationId,
            authorId: childItem.authorId,
            parentId: currentItemId,
            price: childItem.price,
            visibility: childItem.visibility,
            images: []  // Don't modify images - they contain signed URLs, not file IDs
        )

        let updatedChild = try await itemService.updateItem(id: childId, request)

        // Add to local children list
        children.append(updatedChild)
    }

    /// Remove a child item by its ID
    public func removeChildById(_ childId: Int) async throws {
        // Find the child in our local list to get its data
        guard let childItem = children.first(where: { $0.id == childId }) else { return }

        // Create update request with nil parentId
        let request = UpdateItemRequest(
            title: childItem.title,
            description: childItem.description,
            categoryId: childItem.categoryId,
            locationId: childItem.locationId,
            authorId: childItem.authorId,
            parentId: nil,
            price: childItem.price,
            visibility: childItem.visibility,
            images: []  // Don't modify images - they contain signed URLs, not file IDs
        )

        _ = try await itemService.updateItem(id: childId, request)

        // Remove from local children list
        children.removeAll { $0.id == childId }
    }

    // MARK: - Content Management

    /// Create a new content for this item
    public func createContent(type: Content.ContentType, formData: [String: AnyCodable]) async throws {
        guard let itemId = item?.id else { return }

        let pending = PendingContent(type: type, formData: formData)
        let created = try await contentService.createContent(itemId: itemId, pending.asContentRequest)
        contents.append(created)
    }

    /// Delete an existing content
    public func deleteContent(id: Int) async throws {
        try await contentService.deleteContent(id: id)
        contents.removeAll { $0.id == id }
    }
}
