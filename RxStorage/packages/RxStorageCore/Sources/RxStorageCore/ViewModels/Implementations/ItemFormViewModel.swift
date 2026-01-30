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
    public var imageURLs: [String] = []

    // Reference data
    public private(set) var categories: [Category] = []
    public private(set) var locations: [Location] = []
    public private(set) var authors: [Author] = []
    public private(set) var parentItems: [StorageItem] = []

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
    private let uploadManager: UploadManager

    // MARK: - Initialization

    public init(
        item: StorageItem? = nil,
        itemService: ItemServiceProtocol = ItemService(),
        categoryService: CategoryServiceProtocol = CategoryService(),
        locationService: LocationServiceProtocol = LocationService(),
        authorService: AuthorServiceProtocol = AuthorService(),
        uploadManager: UploadManager = .shared
    ) {
        self.item = item
        self.itemService = itemService
        self.categoryService = categoryService
        self.locationService = locationService
        self.authorService = authorService
        self.uploadManager = uploadManager

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
            categories = try await categoryService.fetchCategories()
        } catch {
            print("Failed to load categories: \(error)")
        }

        do {
            locations = try await locationService.fetchLocations()
        } catch {
            print("Failed to load locations: \(error)")
        }

        do {
            authors = try await authorService.fetchAuthors()
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

    public func submit() async throws {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let priceValue = price.isEmpty ? nil : Double(price)

            let request = NewItemRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                categoryId: selectedCategoryId,
                locationId: selectedLocationId,
                authorId: selectedAuthorId,
                parentId: selectedParentId,
                price: priceValue,
                visibility: visibility,
                images: allImageReferences
            )

            if let existingItem = item {
                // Update
                _ = try await itemService.updateItem(id: existingItem.id, request)
            } else {
                // Create
                _ = try await itemService.createItem(request)
            }

            isSubmitting = false
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

        return created
    }

    public func createLocation(title: String, latitude: Double, longitude: Double) async throws -> Location {
        let request = NewLocationRequest(title: title, latitude: latitude, longitude: longitude)
        let created = try await locationService.createLocation(request)

        // Add to local list
        locations.append(created)

        return created
    }

    public func createAuthor(name: String, bio: String?) async throws -> Author {
        let request = NewAuthorRequest(name: name, bio: bio)
        let created = try await authorService.createAuthor(request)

        // Add to local list
        authors.append(created)

        return created
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

    /// Remove a saved image from the imageURLs array
    public func removeSavedImage(at index: Int) {
        guard index >= 0 && index < imageURLs.count else { return }
        imageURLs.remove(at: index)
    }

    /// Get all image references for item submission
    /// Returns file references for completed pending uploads + existing saved images
    public var allImageReferences: [String] {
        // Start with existing saved images (they might be "file:N" or signed URLs)
        var references = imageURLs

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
        imageURLs = item.images
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
