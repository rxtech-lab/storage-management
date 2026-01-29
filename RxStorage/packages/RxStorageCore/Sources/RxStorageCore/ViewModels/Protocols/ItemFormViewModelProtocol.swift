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
    var imageURLs: [String] { get set }

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

    /// Load reference data
    func loadReferenceData() async

    /// Validate form
    func validate() -> Bool

    /// Submit form (create or update)
    func submit() async throws

    /// Inline entity creation
    func createCategory(name: String, description: String?) async throws -> Category
    func createLocation(title: String, latitude: Double, longitude: Double) async throws -> Location
    func createAuthor(name: String, bio: String?) async throws -> Author
}
