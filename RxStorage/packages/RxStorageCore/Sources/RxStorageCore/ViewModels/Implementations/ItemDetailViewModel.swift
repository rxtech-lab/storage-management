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

    public private(set) var item: StorageItemDetail?
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

            // Fetch contents separately (item detail only includes ContentRef, not full Content)
            await fetchContents()
        } catch {
            self.error = error
            isLoading = false
        }
    }

    /// Fetch item for preview (public access, no auth required for public items).
    /// This method is used by App Clips to load items without requiring authentication.
    /// - For public items: loads successfully without auth
    /// - For private items without auth: throws APIError.unauthorized
    /// - For private items with auth but not whitelisted: throws APIError.forbidden
    public func fetchPreviewItem(id: Int) async {
        isLoading = true
        error = nil

        do {
            item = try await itemService.fetchPreviewItem(id: id)
            isLoading = false

            // Use children from item response
            children = item?.children ?? []

            // Fetch contents separately (item detail only includes ContentRef, not full Content)
            await fetchContents()
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
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    public func addChildById(_ childId: Int) async throws -> (parentId: Int, childId: Int) {
        guard let currentItemId = item?.id else {
            throw ItemDetailError.noItemLoaded
        }

        // Fetch the item fresh from API to avoid memory issues with passed objects
        let childItem = try await itemService.fetchItem(id: childId)

        // Create update request with new parentId
        // Convert visibility from response schema to update schema type
        let updateVisibility = UpdateVisibility(rawValue: childItem.visibility.rawValue)
        let request = UpdateItemRequest(
            title: childItem.title,
            description: childItem.description,
            categoryId: childItem.categoryId,
            locationId: childItem.locationId,
            authorId: childItem.authorId,
            parentId: currentItemId,
            price: childItem.price,
            visibility: updateVisibility,
            images: []  // Don't modify images - they contain signed URLs, not file IDs
        )

        let updatedChild = try await itemService.updateItem(id: childId, request)

        // Add to local children list
        children.append(updatedChild)

        return (parentId: currentItemId, childId: childId)
    }

    /// Remove a child item by its ID
    /// Returns tuple of (parentId, childId) for event emission
    @discardableResult
    public func removeChildById(_ childId: Int) async throws -> (parentId: Int, childId: Int) {
        guard let currentItemId = item?.id else {
            throw ItemDetailError.noItemLoaded
        }

        // Find the child in our local list to get its data
        guard let childItem = children.first(where: { $0.id == childId }) else {
            throw ItemDetailError.childNotFound
        }

        // Create update request with nil parentId
        // Convert visibility from response schema to update schema type
        let updateVisibility = UpdateVisibility(rawValue: childItem.visibility.rawValue)
        let request = UpdateItemRequest(
            title: childItem.title,
            description: childItem.description,
            categoryId: childItem.categoryId,
            locationId: childItem.locationId,
            authorId: childItem.authorId,
            parentId: nil,
            price: childItem.price,
            visibility: updateVisibility,
            images: []  // Don't modify images - they contain signed URLs, not file IDs
        )

        _ = try await itemService.updateItem(id: childId, request)

        // Remove from local children list
        children.removeAll { $0.id == childId }

        return (parentId: currentItemId, childId: childId)
    }

    // MARK: - Content Management

    /// Create a new content for this item
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    public func createContent(type: ContentType, formData: [String: AnyCodable]) async throws -> (itemId: Int, contentId: Int) {
        guard let itemId = item?.id else {
            throw ItemDetailError.noItemLoaded
        }

        let pending = PendingContent(type: type, formData: formData)
        let created = try await contentService.createContent(itemId: itemId, pending.asContentRequest)
        contents.append(created)

        return (itemId: itemId, contentId: created.id)
    }

    /// Delete an existing content
    /// Returns tuple of (itemId, contentId) for event emission
    @discardableResult
    public func deleteContent(id: Int) async throws -> (itemId: Int, contentId: Int) {
        guard let itemId = item?.id else {
            throw ItemDetailError.noItemLoaded
        }

        try await contentService.deleteContent(id: id)
        contents.removeAll { $0.id == id }

        return (itemId: itemId, contentId: id)
    }

    /// Update an existing content
    public func updateContent(id: Int, type: ContentType, formData: [String: AnyCodable]) async throws {
        let contentData = ContentData(
            title: formData["title"]?.value as? String,
            description: formData["description"]?.value as? String,
            mimeType: formData["mime_type"]?.value as? String,
            size: formData["size"]?.value as? Int,
            filePath: formData["file_path"]?.value as? String,
            previewImageUrl: formData["preview_image_url"]?.value as? String,
            videoLength: formData["video_length"]?.value as? Int,
            previewVideoUrl: formData["preview_video_url"]?.value as? String
        )
        let request = ContentRequest(type: type, data: contentData)
        let updated = try await contentService.updateContent(id: id, request)

        // Update the content in our local list
        if let index = contents.firstIndex(where: { $0.id == id }) {
            contents[index] = updated
        }
    }
}

// MARK: - Item Detail Errors

public enum ItemDetailError: LocalizedError {
    case noItemLoaded
    case childNotFound

    public var errorDescription: String? {
        switch self {
        case .noItemLoaded:
            return "No item is currently loaded"
        case .childNotFound:
            return "Child item not found"
        }
    }
}
