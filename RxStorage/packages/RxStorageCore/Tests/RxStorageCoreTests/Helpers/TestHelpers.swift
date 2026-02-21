//
//  TestHelpers.swift
//  RxStorageCoreTests
//
//  Test helpers for creating model instances
//

import Foundation
@testable import RxStorageCore

/// Helper methods for creating test data
enum TestHelpers {
    /// Default test date (2024-01-01 00:00:00 UTC)
    static let defaultDate: Date = ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!

    /// Default test user ID
    static let defaultUserId = "test-user-id"

    /// Create a StorageItem for testing
    static func makeStorageItem(
        id: Int = 1,
        userId: String = defaultUserId,
        title: String = "Test Item",
        description: String? = nil,
        originalQrCode: String? = nil,
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int? = nil,
        price: Double? = nil,
        currency: String? = nil,
        visibility: StorageItem.visibilityPayload = .publicAccess,
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate,
        previewUrl: String = "https://example.com/preview/1",
        images: [SignedImage] = [],
        category: CategoryRef? = nil,
        location: LocationRef? = nil,
        author: AuthorRef? = nil
    ) -> StorageItem {
        // Create default refs if not provided
        let categoryRef = category ?? CategoryRef(id: categoryId ?? 0, name: "Default Category")
        let locationRef = location ?? LocationRef(id: locationId ?? 0, title: "Default Location", latitude: 0.0, longitude: 0.0)
        let authorRef = author ?? AuthorRef(id: authorId ?? 0, name: "Default Author")

        return StorageItem(
            id: id,
            userId: userId,
            title: title,
            description: description,
            originalQrCode: originalQrCode,
            categoryId: categoryId,
            locationId: locationId,
            authorId: authorId,
            parentId: parentId,
            price: price,
            currency: currency,
            visibility: visibility,
            createdAt: createdAt,
            updatedAt: updatedAt,
            previewUrl: previewUrl,
            images: images,
            category: StorageItem.categoryPayload(value1: categoryRef),
            location: StorageItem.locationPayload(value1: locationRef),
            author: StorageItem.authorPayload(value1: authorRef)
        )
    }

    /// Create a SignedImage for testing
    static func makeSignedImage(
        id: Int = 1,
        url: String = "https://example.com/signed/image.jpg"
    ) -> SignedImage {
        SignedImage(id: id, url: url)
    }

    /// Create an ImageReference for testing
    static func makeImageReference(
        id: UUID = UUID(),
        url: String = "https://example.com/signed/image.jpg",
        fileId: Int? = nil
    ) -> ImageReference {
        ImageReference(id: id, url: url, fileId: fileId)
    }

    /// Create a Category for testing
    static func makeCategory(
        id: Int = 1,
        userId: String = defaultUserId,
        name: String = "Test Category",
        description: String? = nil,
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate
    ) -> RxStorageCore.Category {
        RxStorageCore.Category(
            id: id,
            userId: userId,
            name: name,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create a Location for testing
    static func makeLocation(
        id: Int = 1,
        userId: String = defaultUserId,
        title: String = "Test Location",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate
    ) -> Location {
        Location(
            id: id,
            userId: userId,
            title: title,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create an Author for testing
    static func makeAuthor(
        id: Int = 1,
        userId: String = defaultUserId,
        name: String = "Test Author",
        bio: String? = nil,
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate
    ) -> Author {
        Author(
            id: id,
            userId: userId,
            name: name,
            bio: bio,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create a CategoryRef for testing
    static func makeCategoryRef(
        id: Int = 1,
        name: String = "Test Category"
    ) -> CategoryRef {
        CategoryRef(id: id, name: name)
    }

    /// Create a LocationRef for testing
    static func makeLocationRef(
        id: Int = 1,
        title: String = "Test Location",
        latitude: Double = 0.0,
        longitude: Double = 0.0
    ) -> LocationRef {
        LocationRef(id: id, title: title, latitude: latitude, longitude: longitude)
    }

    /// Create an AuthorRef for testing
    static func makeAuthorRef(
        id: Int = 1,
        name: String = "Test Author"
    ) -> AuthorRef {
        AuthorRef(id: id, name: name)
    }

    /// Create a StorageItemDetail for testing
    static func makeStorageItemDetail(
        id: Int = 1,
        userId: String = defaultUserId,
        title: String = "Test Item",
        description: String? = nil,
        originalQrCode: String? = nil,
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int? = nil,
        price: Double? = nil,
        currency: String? = nil,
        visibility: StorageItemDetail.visibilityPayload = .publicAccess,
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate,
        previewUrl: String = "https://example.com/preview/1",
        images: [SignedImage] = [],
        category: CategoryRef? = nil,
        location: LocationRef? = nil,
        author: AuthorRef? = nil,
        children: [StorageItem] = [],
        contents: [ContentRef] = [],
        positions: [PositionRef] = [],
        quantity: Int = 0,
        stockHistory: [StockHistoryRef] = []
    ) -> StorageItemDetail {
        // Create default refs if not provided
        let categoryRef = category ?? CategoryRef(id: categoryId ?? 0, name: "Default Category")
        let locationRef = location ?? LocationRef(id: locationId ?? 0, title: "Default Location", latitude: 0.0, longitude: 0.0)
        let authorRef = author ?? AuthorRef(id: authorId ?? 0, name: "Default Author")

        return StorageItemDetail(
            id: id,
            userId: userId,
            title: title,
            description: description,
            originalQrCode: originalQrCode,
            categoryId: categoryId,
            locationId: locationId,
            authorId: authorId,
            parentId: parentId,
            price: price,
            currency: currency,
            visibility: visibility,
            createdAt: createdAt,
            updatedAt: updatedAt,
            previewUrl: previewUrl,
            images: images,
            category: StorageItemDetail.categoryPayload(value1: categoryRef),
            location: StorageItemDetail.locationPayload(value1: locationRef),
            author: StorageItemDetail.authorPayload(value1: authorRef),
            children: children,
            contents: contents,
            positions: positions,
            quantity: quantity,
            stockHistory: stockHistory
        )
    }

    /// Create a ContentRef for testing
    static func makeContentRef(
        id: Int = 1,
        type: ContentRef._typePayload = .image,
        data: ContentRef.dataPayload = ContentRef.dataPayload(),
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate
    ) -> ContentRef {
        ContentRef(
            id: id,
            _type: type,
            data: data,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
