//
//  ItemFormViewModel.swift
//  RxStorageCore
//
//  Item form view model implementation
//

import Foundation
import Observation

/// Item form view model implementation
@Observable
@MainActor
public final class ItemFormViewModel: ItemFormViewModelProtocol {
    // MARK: - Published Properties

    public let item: StorageItem?

    // Form fields
    public var title = ""
    public var description = ""
    public var selectedCategoryId: Int?
    public var selectedLocationId: Int?
    public var selectedAuthorId: Int?
    public var selectedParentId: Int?
    public var price = ""
    public var visibility: Visibility = .publicAccess
    public var existingImages: [ImageReference] = []

    // Position data
    public var positionSchemas: [PositionSchema] = []       // Public for binding (inline creation)
    public private(set) var positions: [Position] = []      // Edit mode: existing positions
    public var pendingPositions: [PendingPosition] = []     // Create/edit: new positions to add

    // Content data
    public var contentSchemas: [ContentSchema] = []         // Predefined schemas (file/image/video)
    public private(set) var contents: [Content] = []        // Edit mode: existing contents
    public var pendingContents: [PendingContent] = []       // Create/edit: new contents to add

    // State
    public private(set) var isLoading = false
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // Upload state
    public private(set) var pendingUploads: [PendingUpload] = []
    public private(set) var isUploading = false

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol
    private let positionSchemaService: PositionSchemaServiceProtocol
    private let positionService: PositionServiceProtocol
    private let contentSchemaService: ContentSchemaServiceProtocol
    private let contentService: ContentServiceProtocol
    private let uploadManager: UploadManager
    private let eventViewModel: EventViewModel?

    // MARK: - Initialization

    public init(
        item: StorageItem? = nil,
        itemService: ItemServiceProtocol = ItemService(),
        positionSchemaService: PositionSchemaServiceProtocol = PositionSchemaService(),
        positionService: PositionServiceProtocol = PositionService(),
        contentSchemaService: ContentSchemaServiceProtocol = ContentSchemaService(),
        contentService: ContentServiceProtocol = ContentService(),
        uploadManager: UploadManager = .shared,
        eventViewModel: EventViewModel? = nil
    ) {
        self.item = item
        self.itemService = itemService
        self.positionSchemaService = positionSchemaService
        self.positionService = positionService
        self.contentSchemaService = contentSchemaService
        self.contentService = contentService
        self.uploadManager = uploadManager
        self.eventViewModel = eventViewModel

        // Populate form if editing
        if let item = item {
            populateForm(from: item)
        }
    }

    // MARK: - Public Methods

    public func loadReferenceData() async {
        isLoading = true

        // Load position schemas
        do {
            positionSchemas = try await positionSchemaService.fetchPositionSchemas(filters: nil)
        } catch {
            print("Failed to load position schemas: \(error)")
        }

        // Load existing positions if editing
        if let itemId = item?.id {
            do {
                positions = try await positionService.fetchItemPositions(itemId: itemId)
            } catch {
                print("Failed to load positions: \(error)")
            }
        }

        // Load content schemas
        do {
            contentSchemas = try await contentSchemaService.fetchContentSchemas()
        } catch {
            print("Failed to load content schemas: \(error)")
        }

        // Load existing contents if editing
        if let itemId = item?.id {
            do {
                contents = try await contentService.fetchItemContents(itemId: itemId)
            } catch {
                print("Failed to load contents: \(error)")
            }
        }

        isLoading = false
    }

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate title
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["title"] = "Title is required"
        }

        // Validate price if provided
        if !price.isEmpty {
            if Double(price) == nil {
                validationErrors["price"] = "Invalid price format"
            }
        }

        return validationErrors.isEmpty
    }

    @discardableResult
    public func submit() async throws -> StorageItem {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let priceValue = price.isEmpty ? nil : Double(price)

            // Convert pending positions to API format
            let positionsData = pendingPositions.isEmpty ? nil : pendingPositions.map { $0.asNewPositionData }

            let result: StorageItem
            if let existingItem = item {
                // Update - use UpdateItemRequest with update visibility type
                let updateVisibility = UpdateVisibility(rawValue: visibility.rawValue)
                let updateRequest = UpdateItemRequest(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    categoryId: selectedCategoryId,
                    locationId: selectedLocationId,
                    authorId: selectedAuthorId,
                    parentId: selectedParentId,
                    price: priceValue,
                    visibility: updateVisibility,
                    images: allImageReferences,
                    positions: positionsData
                )
                result = try await itemService.updateItem(id: existingItem.id, updateRequest)
                eventViewModel?.emit(.itemUpdated(id: result.id))
            } else {
                // Create - use NewItemRequest with insert visibility type
                let insertVisibility = InsertVisibility(rawValue: visibility.rawValue) ?? .privateAccess
                let createRequest = NewItemRequest(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    categoryId: selectedCategoryId,
                    locationId: selectedLocationId,
                    authorId: selectedAuthorId,
                    parentId: selectedParentId,
                    price: priceValue,
                    visibility: insertVisibility,
                    images: allImageReferences,
                    positions: positionsData
                )
                result = try await itemService.createItem(createRequest)
                eventViewModel?.emit(.itemCreated(id: result.id))
            }

            // Clear pending positions after successful save
            pendingPositions.removeAll()

            isSubmitting = false
            return result
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Position Management

    /// Add a pending position to be created with the item
    public func addPendingPosition(schema: PositionSchema, data: [String: AnyCodable]) {
        let pending = PendingPosition(
            positionSchemaId: schema.id,
            schema: schema,
            data: data
        )
        pendingPositions.append(pending)
    }

    /// Remove a pending position
    public func removePendingPosition(id: UUID) {
        pendingPositions.removeAll { $0.id == id }
    }

    /// Delete an existing position (only for edit mode)
    public func removePosition(id: Int) async throws {
        try await positionService.deletePosition(id: id)
        positions.removeAll { $0.id == id }
    }

    // MARK: - Content Management

    /// Add a pending content to be created with the item
    public func addPendingContent(type: ContentType, formData: [String: AnyCodable]) {
        let pending = PendingContent(type: type, formData: formData)
        pendingContents.append(pending)
    }

    /// Remove a pending content
    public func removePendingContent(id: UUID) {
        pendingContents.removeAll { $0.id == id }
    }

    /// Create content for existing item (edit mode only)
    public func createContent(type: ContentType, formData: [String: AnyCodable]) async throws {
        guard let itemId = item?.id else { return }

        let pending = PendingContent(type: type, formData: formData)
        let created = try await contentService.createContent(itemId: itemId, pending.asContentRequest)
        contents.append(created)
    }

    /// Delete an existing content (only for edit mode)
    public func removeContent(id: Int) async throws {
        try await contentService.deleteContent(id: id)
        contents.removeAll { $0.id == id }
    }

    // MARK: - Image Upload

    /// Add an image from local file URL to pending uploads
    public func addImage(from localURL: URL) {
        let filename = localURL.lastPathComponent
        let contentType = MIMEType.from(url: localURL)

        // Get file size
        let fileSize: Int64
        if let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
           let size = attributes[.size] as? Int64
        {
            fileSize = size
        } else {
            fileSize = 0
        }

        let pending = PendingUpload(
            localURL: localURL,
            filename: filename,
            contentType: contentType,
            fileSize: fileSize
        )
        pendingUploads.append(pending)
    }

    /// Upload all pending images
    public func uploadPendingImages() async {
        isUploading = true

        for index in pendingUploads.indices {
            guard pendingUploads[index].status == .pending else { continue }

            pendingUploads[index].status = .gettingPresignedURL

            do {
                pendingUploads[index].status = .uploading

                let result = try await uploadManager.upload(
                    file: pendingUploads[index].localURL,
                    onProgress: { [weak self] uploaded, total in
                        Task { @MainActor in
                            guard let self = self, index < self.pendingUploads.count else { return }
                            self.pendingUploads[index].progress = Double(uploaded) / Double(max(total, 1))
                        }
                    }
                )

                pendingUploads[index].fileId = result.fileId
                pendingUploads[index].publicUrl = result.publicUrl
                pendingUploads[index].progress = 1.0
                pendingUploads[index].status = .completed

            } catch {
                let errorMessage = error.localizedDescription
                pendingUploads[index].status = .failed(errorMessage)
            }
        }

        isUploading = false
    }

    /// Cancel an in-progress upload
    public func cancelUpload(id: UUID) async {
        if let index = pendingUploads.firstIndex(where: { $0.id == id }) {
            await uploadManager.cancel(uploadId: id)
            pendingUploads[index].status = .cancelled
        }
    }

    /// Remove a pending upload (before item is saved)
    public func removePendingUpload(id: UUID) {
        pendingUploads.removeAll { $0.id == id }
    }

    /// Remove an existing image
    public func removeSavedImage(at index: Int) {
        guard index >= 0 && index < existingImages.count else { return }
        existingImages.remove(at: index)
    }

    /// Get all image references for item submission
    /// Returns file references for completed pending uploads + existing saved images
    public var allImageReferences: [String] {
        // Start with existing images, converted to file references
        var references = existingImages.map { $0.fileReference }

        // Add completed pending uploads as "file:N" references
        let completedReferences = pendingUploads.compactMap { $0.fileReference }
        references.append(contentsOf: completedReferences)

        return references
    }

    // MARK: - Private Methods

    private func populateForm(from item: StorageItem) {
        title = item.title
        description = item.description ?? ""
        selectedCategoryId = item.categoryId
        selectedLocationId = item.locationId
        selectedAuthorId = item.authorId
        selectedParentId = item.parentId
        price = item.price.map { String($0) } ?? ""
        visibility = item.visibility
        // Convert signed images to ImageReference objects
        existingImages = item.images.map { ImageReference(url: $0.url, fileId: $0.id) }

        // Note: Reference data (categories, locations, authors) and embedded data
        // (positions, contents) are loaded via loadReferenceData() which fetches
        // the full response schemas needed for form display.
    }
}

// MARK: - Form Error

public enum FormError: LocalizedError, Sendable {
    case validationFailed

    public var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Please fix the validation errors"
        }
    }
}
