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
    public var visibility: StorageItem.Visibility = .public
    public var existingImages: [ImageReference] = []

    // Reference data
    public private(set) var categories: [Category] = []
    public private(set) var locations: [Location] = []
    public private(set) var authors: [Author] = []
    public private(set) var parentItems: [StorageItem] = []

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
    private let categoryService: CategoryServiceProtocol
    private let locationService: LocationServiceProtocol
    private let authorService: AuthorServiceProtocol
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
        categoryService: CategoryServiceProtocol = CategoryService(),
        locationService: LocationServiceProtocol = LocationService(),
        authorService: AuthorServiceProtocol = AuthorService(),
        positionSchemaService: PositionSchemaServiceProtocol = PositionSchemaService(),
        positionService: PositionServiceProtocol = PositionService(),
        contentSchemaService: ContentSchemaServiceProtocol = ContentSchemaService(),
        contentService: ContentServiceProtocol = ContentService(),
        uploadManager: UploadManager = .shared,
        eventViewModel: EventViewModel? = nil
    ) {
        self.item = item
        self.itemService = itemService
        self.categoryService = categoryService
        self.locationService = locationService
        self.authorService = authorService
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

        // Fetch reference data sequentially (all on MainActor)
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

        do {
            let items = try await itemService.fetchItems(filters: nil)
            if let currentItemId = item?.id {
                parentItems = items.filter { $0.id != currentItemId }
            } else {
                parentItems = items
            }
        } catch {
            print("Failed to load parent items: \(error)")
        }

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

            let request = NewItemRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                categoryId: selectedCategoryId,
                locationId: selectedLocationId,
                authorId: selectedAuthorId,
                parentId: selectedParentId,
                price: priceValue,
                visibility: visibility,
                images: allImageReferences,
                positions: positionsData
            )

            let result: StorageItem
            if let existingItem = item {
                // Update
                result = try await itemService.updateItem(id: existingItem.id, request)
                eventViewModel?.emit(.itemUpdated(id: result.id))
            } else {
                // Create
                result = try await itemService.createItem(request)
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

    // MARK: - Inline Entity Creation

    public func createCategory(name: String, description: String?) async throws -> Category {
        let request = NewCategoryRequest(name: name, description: description)
        let created = try await categoryService.createCategory(request)

        // Add to local list
        categories.append(created)

        // Emit event
        eventViewModel?.emit(.categoryCreated(id: created.id))

        return created
    }

    public func createLocation(title: String, latitude: Double, longitude: Double) async throws -> Location {
        let request = NewLocationRequest(title: title, latitude: latitude, longitude: longitude)
        let created = try await locationService.createLocation(request)

        // Add to local list
        locations.append(created)

        // Emit event
        eventViewModel?.emit(.locationCreated(id: created.id))

        return created
    }

    public func createAuthor(name: String, bio: String?) async throws -> Author {
        let request = NewAuthorRequest(name: name, bio: bio)
        let created = try await authorService.createAuthor(request)

        // Add to local list
        authors.append(created)

        // Emit event
        eventViewModel?.emit(.authorCreated(id: created.id))

        return created
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
    public func addPendingContent(type: Content.ContentType, formData: [String: AnyCodable]) {
        let pending = PendingContent(type: type, formData: formData)
        pendingContents.append(pending)
    }

    /// Remove a pending content
    public func removePendingContent(id: UUID) {
        pendingContents.removeAll { $0.id == id }
    }

    /// Create content for existing item (edit mode only)
    public func createContent(type: Content.ContentType, formData: [String: AnyCodable]) async throws {
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
        existingImages = item.images

        // Pre-populate reference data with embedded objects for immediate display
        // This prevents the "None" -> "Selected" visual flash when editing
        if let category = item.category {
            categories = [category]
        }
        if let location = item.location {
            locations = [location]
        }
        if let author = item.author {
            authors = [author]
        }
        // Pre-populate positions from embedded data
        if let itemPositions = item.positions {
            positions = itemPositions
        }
        // Pre-populate contents from embedded data
        if let itemContents = item.contents {
            contents = itemContents
        }
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
