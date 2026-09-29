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
        id: String = "1",
        userId: String = defaultUserId,
        title: String = "Test Item",
        description: String? = nil,
        originalQrCode: String? = nil,
        categoryId: String? = nil,
        locationId: String? = nil,
        authorId: String? = nil,
        parentId: String? = nil,
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
        let categoryRef = category ?? CategoryRef(id: categoryId ?? "0", name: "Default Category")
        let locationRef = location ?? LocationRef(id: locationId ?? "0", title: "Default Location", latitude: 0.0, longitude: 0.0)
        let authorRef = author ?? AuthorRef(id: authorId ?? "0", name: "Default Author")

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
        id: String = "1",
        url: String = "https://example.com/signed/image.jpg"
    ) -> SignedImage {
        SignedImage(id: id, url: url)
    }

    /// Create an ImageReference for testing
    static func makeImageReference(
        id: UUID = UUID(),
        url: String = "https://example.com/signed/image.jpg",
        fileId: String? = nil
    ) -> ImageReference {
        ImageReference(id: id, url: url, fileId: fileId)
    }

    /// Create a Category for testing
    static func makeCategory(
        id: String = "1",
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
        id: String = "1",
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
        id: String = "1",
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
        id: String = "1",
        name: String = "Test Category"
    ) -> CategoryRef {
        CategoryRef(id: id, name: name)
    }

    /// Create a LocationRef for testing
    static func makeLocationRef(
        id: String = "1",
        title: String = "Test Location",
        latitude: Double = 0.0,
        longitude: Double = 0.0
    ) -> LocationRef {
        LocationRef(id: id, title: title, latitude: latitude, longitude: longitude)
    }

    /// Create an AuthorRef for testing
    static func makeAuthorRef(
        id: String = "1",
        name: String = "Test Author"
    ) -> AuthorRef {
        AuthorRef(id: id, name: name)
    }

    /// Create a StorageItemDetail for testing
    static func makeStorageItemDetail(
        id: String = "1",
        userId: String = defaultUserId,
        title: String = "Test Item",
        description: String? = nil,
        originalQrCode: String? = nil,
        categoryId: String? = nil,
        locationId: String? = nil,
        authorId: String? = nil,
        parentId: String? = nil,
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
        parent: ParentRef? = nil,
        mainQuantity: Int? = nil,
        stocks: [ItemStock] = [],
        storedStocks: [StoredStock] = [],
        stockHistory: [StockHistoryRef] = [],
        tags: [TagRef] = []
    ) -> StorageItemDetail {
        // Create default refs if not provided
        let categoryRef = category ?? CategoryRef(id: categoryId ?? "0", name: "Default Category")
        let locationRef = location ?? LocationRef(id: locationId ?? "0", title: "Default Location", latitude: 0.0, longitude: 0.0)
        let authorRef = author ?? AuthorRef(id: authorId ?? "0", name: "Default Author")

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
            totalChildren: children.count,
            contents: contents,
            totalContents: contents.count,
            positions: positions,
            quantity: quantity,
            parent: parent.map { StorageItemDetail.parentPayload(value1: $0) },
            mainQuantity: mainQuantity ?? quantity,
            stocks: stocks,
            storedStocks: storedStocks,
            stockHistory: stockHistory,
            tags: tags
        )
    }

    /// Create a ContentRef for testing
    static func makeContentRef(
        id: String = "1",
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

// MARK: - ISO Jobs

extension TestHelpers {
    /// Create an IsoJob for testing
    static func makeIsoJob(
        id: String = "job-1",
        kind: IsoJobKind = .generate,
        title: String = "backup",
        status: IsoJobStatus = .running,
        progress: Double = 0.5
    ) -> IsoJob {
        IsoJob(
            id: id,
            userId: defaultUserId,
            kind: kind,
            title: title,
            status: status,
            hostName: "studio-mac",
            progress: progress,
            doneCount: 1,
            totalCount: 2,
            doneBytes: 50,
            totalBytes: 100,
            message: nil,
            error: nil,
            startedAt: defaultDate,
            finishedAt: nil,
            createdAt: defaultDate,
            updatedAt: defaultDate
        )
    }

    /// Create an IsoJobTask for testing
    static func makeIsoJobTask(
        id: String,
        section: Components.Schemas.IsoJobTaskSection,
        name: String,
        status: String = "copying",
        progress: Double = 0.5
    ) -> IsoJobTask {
        IsoJobTask(
            section: section,
            name: name,
            status: status,
            detail: nil,
            progress: progress,
            doneBytes: 50,
            totalBytes: 100,
            error: nil,
            id: id,
            position: 0
        )
    }

    /// Create an IsoJobDetail for testing
    static func makeIsoJobDetail(
        id: String = "job-1",
        kind: IsoJobKind = .burn,
        status: IsoJobStatus = .running,
        tasks: [IsoJobTask] = []
    ) -> IsoJobDetail {
        IsoJobDetail(
            id: id,
            userId: defaultUserId,
            kind: kind,
            title: "Burn backup_1.iso",
            status: status,
            hostName: "studio-mac",
            progress: 0.5,
            doneCount: 1,
            totalCount: 2,
            doneBytes: 50,
            totalBytes: 100,
            message: nil,
            error: nil,
            startedAt: defaultDate,
            finishedAt: nil,
            createdAt: defaultDate,
            updatedAt: defaultDate,
            tasks: tasks
        )
    }

    static func page<T: Sendable>(_ data: [T], nextCursor: String? = nil, total: Int? = nil) -> PaginatedResponse<T> {
        PaginatedResponse(
            data: data,
            pagination: PaginationState(
                hasNextPage: nextCursor != nil,
                hasPrevPage: false,
                nextCursor: nextCursor,
                prevCursor: nil,
                totalCount: total ?? data.count
            )
        )
    }
}
