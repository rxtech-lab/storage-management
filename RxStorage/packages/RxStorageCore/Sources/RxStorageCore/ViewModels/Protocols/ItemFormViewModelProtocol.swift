//
//  ItemFormViewModelProtocol.swift
//  RxStorageCore
//
//  Protocol for item form view model
//

import Foundation

/// Protocol for item form view model operations
@MainActor
public protocol ItemFormViewModelProtocol: AnyObject, Observable {
    /// Item being edited (nil for create mode)
    var item: StorageItem? { get }

    /// Form data
    var title: String { get set }
    var description: String { get set }
    var selectedCategoryId: Int? { get set }
    var selectedLocationId: Int? { get set }
    var selectedAuthorId: Int? { get set }
    var selectedParentId: Int? { get set }
    var price: String { get set }
    var visibility: StorageItem.Visibility { get set }
    var existingImages: [ImageReference] { get set }

    /// Reference data
    var categories: [Category] { get }
    var locations: [Location] { get }
    var authors: [Author] { get }
    var parentItems: [StorageItem] { get }

    /// State
    var isLoading: Bool { get }
    var isSubmitting: Bool { get }
    var error: Error? { get }
    var validationErrors: [String: String] { get }

    /// Upload state
    var pendingUploads: [PendingUpload] { get }
    var isUploading: Bool { get }

    /// Load reference data
    func loadReferenceData() async

    /// Validate form
    func validate() -> Bool

    /// Submit form (create or update)
    @discardableResult
    func submit() async throws -> StorageItem

    /// Inline entity creation
    func createCategory(name: String, description: String?) async throws -> Category
    func createLocation(title: String, latitude: Double, longitude: Double) async throws -> Location
    func createAuthor(name: String, bio: String?) async throws -> Author

    // MARK: - Image Upload

    /// Add an image from local file URL to pending uploads
    func addImage(from localURL: URL)

    /// Upload all pending images
    func uploadPendingImages() async

    /// Cancel an in-progress upload
    func cancelUpload(id: UUID) async

    /// Remove a pending upload (before item is saved)
    func removePendingUpload(id: UUID)

    /// Remove an existing image
    func removeSavedImage(at index: Int)

    /// Get all image references for item submission
    /// Returns file references for pending uploads + existing saved images
    var allImageReferences: [String] { get }
}
