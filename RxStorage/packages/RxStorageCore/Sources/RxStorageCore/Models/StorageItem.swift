//
//  StorageItem.swift
//  RxStorageCore
//
//  Main storage item model matching API schema
//

import Foundation

/// Main storage item entity
public struct StorageItem: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let description: String?
    public let categoryId: Int?
    public let locationId: Int?
    public let authorId: Int?
    public let parentId: Int?
    public let price: Double?
    public let visibility: Visibility
    public let images: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let previewUrl: String

    // Relations (optional, populated by API)
    public let category: Category?
    public let location: Location?
    public let author: Author?

    public init(
        id: Int,
        title: String,
        description: String?,
        categoryId: Int?,
        locationId: Int?,
        authorId: Int?,
        parentId: Int?,
        price: Double?,
        visibility: Visibility,
        images: [String],
        createdAt: Date,
        updatedAt: Date,
        category: Category? = nil,
        location: Location? = nil,
        author: Author? = nil,
        previewUrl: String,

    ) {
        self.id = id
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.price = price
        self.visibility = visibility
        self.images = images
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.location = location
        self.author = author
        self.previewUrl = previewUrl
    }

    /// Item visibility
    public enum Visibility: String, Codable, CaseIterable, Sendable {
        case `public`
        case `private`

        public var displayName: String {
            switch self {
            case .public: return "Public"
            case .private: return "Private"
            }
        }
    }

    /// Check if item has a parent (is a child item)
    public var isChildItem: Bool {
        parentId != nil
    }

    /// Check if item is root level
    public var isRootItem: Bool {
        parentId == nil
    }
}

/// Request body for creating a new item
public struct NewItemRequest: Codable, Sendable {
    public let title: String
    public let description: String?
    public let categoryId: Int?
    public let locationId: Int?
    public let authorId: Int?
    public let parentId: Int?
    public let price: Double?
    public let visibility: StorageItem.Visibility
    public let images: [String]
    public let positions: [NewPositionData]?

    public init(
        title: String,
        description: String? = nil,
        categoryId: Int? = nil,
        locationId: Int? = nil,
        authorId: Int? = nil,
        parentId: Int? = nil,
        price: Double? = nil,
        visibility: StorageItem.Visibility = .public,
        images: [String] = [],
        positions: [NewPositionData]? = nil
    ) {
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.price = price
        self.visibility = visibility
        self.images = images
        self.positions = positions
    }
}

/// Request body for updating an item
public typealias UpdateItemRequest = NewItemRequest

/// Item preview with additional content data (used by App Clips)
public struct ItemPreview: Codable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let description: String?
    public let categoryId: Int?
    public let locationId: Int?
    public let authorId: Int?
    public let parentId: Int?
    public let price: Double?
    public let visibility: StorageItem.Visibility
    public let images: [String]
    public let createdAt: Date
    public let updatedAt: Date

    // Relations
    public let category: Category?
    public let location: Location?
    public let author: Author?

    // Additional preview data
    public let contents: [Content]

    public init(
        id: Int,
        title: String,
        description: String?,
        categoryId: Int?,
        locationId: Int?,
        authorId: Int?,
        parentId: Int?,
        price: Double?,
        visibility: StorageItem.Visibility,
        images: [String],
        createdAt: Date,
        updatedAt: Date,
        category: Category?,
        location: Location?,
        author: Author?,
        contents: [Content]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.locationId = locationId
        self.authorId = authorId
        self.parentId = parentId
        self.price = price
        self.visibility = visibility
        self.images = images
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.location = location
        self.author = author
        self.contents = contents
    }
}

/// QR code data for an item
public struct QRCodeData: Codable, Sendable {
    public let itemId: Int
    public let itemTitle: String
    public let previewUrl: String
    public let qrCodeDataUrl: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemTitle = "item_title"
        case previewUrl = "preview_url"
        case qrCodeDataUrl = "qr_code_data_url"
    }

    public init(
        itemId: Int,
        itemTitle: String,
        previewUrl: String,
        qrCodeDataUrl: String
    ) {
        self.itemId = itemId
        self.itemTitle = itemTitle
        self.previewUrl = previewUrl
        self.qrCodeDataUrl = qrCodeDataUrl
    }
}
