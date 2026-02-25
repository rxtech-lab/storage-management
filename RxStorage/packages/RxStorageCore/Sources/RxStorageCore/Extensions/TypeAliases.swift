//
//  TypeAliases.swift
//  RxStorageCore
//
//  Type aliases mapping generated OpenAPI types to simpler names
//

import Foundation

// MARK: - Response Schema Type Aliases

/// Storage item with category, location, author info
public typealias StorageItem = Components.Schemas.ItemResponseSchema

/// Detailed item with children, contents, and positions
public typealias StorageItemDetail = Components.Schemas.ItemDetailResponseSchema

/// Category entity
public typealias Category = Components.Schemas.CategoryResponseSchema

/// Location entity
public typealias Location = Components.Schemas.LocationResponseSchema

/// Author entity
public typealias Author = Components.Schemas.AuthorResponseSchema

/// Position schema entity
public typealias PositionSchema = Components.Schemas.PositionSchemaResponseSchema

/// Position entity
public typealias Position = Components.Schemas.PositionResponseSchema

/// Content attachment entity
public typealias Content = Components.Schemas.ContentResponseSchema

/// Content schema definition
public typealias ContentSchema = Components.Schemas.ContentSchemaDefinitionSchema

/// Dashboard statistics
public typealias DashboardStats = Components.Schemas.DashboardStatsResponseSchema

/// Dashboard recent item (simplified item for dashboard display)
public typealias DashboardRecentItem = Components.Schemas.DashboardRecentItemSchema

/// Whitelist entry
public typealias Whitelist = Components.Schemas.WhitelistResponseSchema

/// Stock history entry
public typealias StockHistory = Components.Schemas.StockHistoryResponseSchema

/// Presigned upload response
public typealias PresignedUploadResponse = Components.Schemas.PresignedUploadResponseSchema

/// Account deletion status response
public typealias AccountDeletionStatus = Components.Schemas.AccountDeletionStatusResponseSchema

/// Account deletion request response
public typealias AccountDeletionRequestResponse = Components.Schemas.AccountDeletionRequestResponseSchema

/// Account deletion record
public typealias AccountDeletion = Components.Schemas.AccountDeletionResponseSchema

// MARK: - Request Schema Type Aliases

/// Request to create an item
public typealias NewItemRequest = Components.Schemas.ItemInsertSchema

/// Request to update an item
public typealias UpdateItemRequest = Components.Schemas.ItemUpdateSchema

/// Request to create a category
public typealias NewCategoryRequest = Components.Schemas.CategoryInsertSchema

/// Request to update a category
public typealias UpdateCategoryRequest = Components.Schemas.CategoryUpdateSchema

/// Request to create a location
public typealias NewLocationRequest = Components.Schemas.LocationInsertSchema

/// Request to update a location
public typealias UpdateLocationRequest = Components.Schemas.LocationUpdateSchema

/// Request to create an author
public typealias NewAuthorRequest = Components.Schemas.AuthorInsertSchema

/// Request to update an author
public typealias UpdateAuthorRequest = Components.Schemas.AuthorUpdateSchema

/// Request to create a position schema
public typealias NewPositionSchemaRequest = Components.Schemas.PositionSchemaInsertSchema

/// Request to update a position schema
public typealias UpdatePositionSchemaRequest = Components.Schemas.PositionSchemaUpdateSchema

/// Request to create content
public typealias NewContentRequest = Components.Schemas.ContentInsertSchema

/// Request to update content
public typealias UpdateContentRequest = Components.Schemas.ContentUpdateSchema

/// Request for presigned upload URL
public typealias PresignedUploadRequest = Components.Schemas.PresignedUploadRequestSchema

/// Request to set item parent
public typealias SetParentRequest = Components.Schemas.SetParentRequestSchema

/// Request to add to whitelist
public typealias WhitelistAddRequest = Components.Schemas.WhitelistAddRequestSchema

/// Request to create a stock history entry
public typealias NewStockHistoryRequest = Components.Schemas.StockHistoryInsertSchema

// MARK: - Paginated Response Type Aliases

/// Paginated items response
public typealias PaginatedItemsResponse = Components.Schemas.PaginatedItemsResponse

/// Paginated categories response
public typealias PaginatedCategoriesResponse = Components.Schemas.PaginatedCategoriesResponse

/// Paginated locations response
public typealias PaginatedLocationsResponse = Components.Schemas.PaginatedLocationsResponse

/// Paginated authors response
public typealias PaginatedAuthorsResponse = Components.Schemas.PaginatedAuthorsResponse

/// Paginated position schemas response
public typealias PaginatedPositionSchemasResponse = Components.Schemas.PaginatedPositionSchemasResponse

/// Pagination info
public typealias PaginationInfo = Components.Schemas.PaginationInfo

// MARK: - Reference Type Aliases (for nested objects)

/// Category reference in item response
public typealias CategoryRef = Components.Schemas.CategoryRefSchema

/// Location reference in item response
public typealias LocationRef = Components.Schemas.LocationRefSchema

/// Author reference in item response
public typealias AuthorRef = Components.Schemas.AuthorRefSchema

/// Content reference in item detail
public typealias ContentRef = Components.Schemas.ContentRefSchema

/// Position reference in item detail
public typealias PositionRef = Components.Schemas.PositionRefSchema

/// Stock history reference in item detail
public typealias StockHistoryRef = Components.Schemas.StockHistoryRefSchema

/// Signed image with id and URL
public typealias SignedImage = Components.Schemas.SignedImageSchema

// MARK: - Content Data Type Aliases

/// File content data
public typealias FileContentData = Components.Schemas.FileContentDataSchema

/// Image content data
public typealias ImageContentData = Components.Schemas.ImageContentDataSchema

/// Video content data
public typealias VideoContentData = Components.Schemas.VideoContentDataSchema

// MARK: - Enum Type Aliases

/// Content type enum (file, image, video)
public typealias ContentType = Components.Schemas.ContentResponseSchema._typePayload

/// Item visibility enum (publicAccess, privateAccess)
public typealias Visibility = Components.Schemas.ItemResponseSchema.visibilityPayload

/// Item visibility for insert requests
public typealias InsertVisibility = Components.Schemas.ItemInsertSchema.visibilityPayload

/// Item visibility for update requests
public typealias UpdateVisibility = Components.Schemas.ItemUpdateSchema.visibilityPayload

/// Item visibility for query filters
public typealias QueryVisibility = Components.Schemas.ItemsQueryParams.visibilityPayload

// MARK: - Identifiable Conformance

extension Components.Schemas.ItemResponseSchema: Identifiable {}
extension Components.Schemas.ItemDetailResponseSchema: Identifiable {}
extension Components.Schemas.CategoryResponseSchema: Identifiable {}
extension Components.Schemas.LocationResponseSchema: Identifiable {}
extension Components.Schemas.AuthorResponseSchema: Identifiable {}
extension Components.Schemas.PositionSchemaResponseSchema: Identifiable {}
extension Components.Schemas.PositionResponseSchema: Identifiable {}
extension Components.Schemas.ContentResponseSchema: Identifiable {}
extension Components.Schemas.DashboardRecentItemSchema: Identifiable {}
extension Components.Schemas.StockHistoryResponseSchema: Identifiable {}

// Reference schemas also need Identifiable
extension Components.Schemas.CategoryRefSchema: Identifiable {}
extension Components.Schemas.LocationRefSchema: Identifiable {}
extension Components.Schemas.AuthorRefSchema: Identifiable {}
extension Components.Schemas.ContentRefSchema: Identifiable {}
extension Components.Schemas.PositionRefSchema: Identifiable {}
extension Components.Schemas.StockHistoryRefSchema: Identifiable {}

// MARK: - Content Convenience Extensions

public extension Components.Schemas.ContentResponseSchema {
    /// Convenience property to access _type as type
    var type: _typePayload {
        _type
    }

    /// Convert data payload to ContentData helper type
    var contentData: ContentData {
        let props = data.additionalProperties
        return ContentData(
            title: props["title"]?.value as? String,
            description: props["description"]?.value as? String,
            mimeType: props["mime_type"]?.value as? String,
            size: (props["size"]?.value as? Double).flatMap { Int($0) },
            filePath: props["file_path"]?.value as? String,
            previewImageUrl: props["preview_image_url"]?.value as? String,
            videoLength: (props["video_length"]?.value as? Double).flatMap { Int($0) },
            previewVideoUrl: props["preview_video_url"]?.value as? String
        )
    }
}

// MARK: - StorageItemDetail to StorageItem Conversion

public extension Components.Schemas.ItemDetailResponseSchema {
    /// Convert to StorageItem (ItemResponseSchema) for use in list views
    func toStorageItem() -> StorageItem {
        // Convert payload types by extracting the underlying ref schema and wrapping in new payload
        let categoryPayload = category.map { StorageItem.categoryPayload(value1: $0.value1) }
        let locationPayload = location.map { StorageItem.locationPayload(value1: $0.value1) }
        let authorPayload = author.map { StorageItem.authorPayload(value1: $0.value1) }

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
            visibility: StorageItem.visibilityPayload(rawValue: visibility.rawValue) ?? .publicAccess,
            createdAt: createdAt,
            updatedAt: updatedAt,
            previewUrl: previewUrl,
            images: images,
            category: categoryPayload,
            location: locationPayload,
            author: authorPayload
        )
    }
}

// MARK: - ContentRef to Content Conversion

public extension Components.Schemas.ContentRefSchema {
    /// Convert ContentRefSchema to ContentResponseSchema for display in views
    /// - Parameter itemId: The parent item ID (not included in ContentRefSchema)
    func toContent(itemId: Int) -> Content {
        // Map type payload
        let contentType: Content._typePayload
        switch _type {
        case .file: contentType = .file
        case .image: contentType = .image
        case .video: contentType = .video
        }

        return Content(
            id: id,
            itemId: itemId,
            _type: contentType,
            data: Content.dataPayload(additionalProperties: data.additionalProperties),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - ContentType Convenience Extensions

public extension Components.Schemas.ContentResponseSchema._typePayload {
    /// Display name for the content type
    var displayName: String {
        switch self {
        case .file: return "File"
        case .image: return "Image"
        case .video: return "Video"
        }
    }

    /// Icon name for the content type
    var icon: String {
        switch self {
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "video.fill"
        }
    }
}
