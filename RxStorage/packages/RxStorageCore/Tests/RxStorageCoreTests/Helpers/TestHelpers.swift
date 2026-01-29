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
    static let defaultDate: Date = {
        ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!
    }()

    /// Create a StorageItem for testing
    static func makeStorageItem(
        id: Int = 1,
        title: String = "Test Item",
        description: String? = nil,
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int? = nil,
        price: Double? = nil,
        visibility: StorageItem.Visibility = .public,
        images: [String] = [],
        createdAt: Date = defaultDate,
        updatedAt: Date = defaultDate,
        category: RxStorageCore.Category? = nil,
        location: Location? = nil,
        author: Author? = nil,
        previewUrl: String = "https://example.com/preview/1"
    ) -> StorageItem {
        StorageItem(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            locationId: locationId,
            authorId: authorId,
            parentId: parentId,
            price: price,
            visibility: visibility,
            images: images,
            createdAt: createdAt,
            updatedAt: updatedAt,
            category: category,
            location: location,
            author: author,
            previewUrl: previewUrl
        )
    }

    /// Create a Category for testing
    static func makeCategory(
        id: Int = 1,
        userId: String? = nil,
        name: String = "Test Category",
        description: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
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
        title: String = "Test Location",
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> Location {
        Location(
            id: id,
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
        name: String = "Test Author",
        bio: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> Author {
        Author(
            id: id,
            name: name,
            bio: bio,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create QRCodeData for testing
    static func makeQRCodeData(
        itemId: Int = 1,
        itemTitle: String = "Test Item",
        previewUrl: String = "https://example.com/preview/1",
        qrCodeDataUrl: String = "data:image/png;base64,test"
    ) -> QRCodeData {
        QRCodeData(
            itemId: itemId,
            itemTitle: itemTitle,
            previewUrl: previewUrl,
            qrCodeDataUrl: qrCodeDataUrl
        )
    }
}
