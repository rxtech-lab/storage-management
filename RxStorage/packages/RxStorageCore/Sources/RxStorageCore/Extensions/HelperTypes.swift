//
//  HelperTypes.swift
//  RxStorageCore
//
//  Helper types for forms and pending operations
//

import Foundation
import OpenAPIRuntime

// MARK: - Image Reference

/// Reference to an image (either saved or from file upload)
public struct ImageReference: Sendable, Identifiable {
    public let id: UUID
    public let url: String
    public let fileId: Int?

    public init(id: UUID = UUID(), url: String, fileId: Int?) {
        self.id = id
        self.url = url
        self.fileId = fileId
    }

    /// Get the file reference for API submission ("file:N" format)
    public var fileReference: String {
        if let fileId = fileId {
            return "file:\(fileId)"
        }
        return url
    }
}

// MARK: - Pending Position

/// A position waiting to be saved with an item
public struct PendingPosition: Identifiable, Sendable {
    public let id: UUID
    public let positionSchemaId: Int
    public let schema: PositionSchema
    public let data: [String: AnyCodable]

    public init(
        id: UUID = UUID(),
        positionSchemaId: Int,
        schema: PositionSchema,
        data: [String: AnyCodable]
    ) {
        self.id = id
        self.positionSchemaId = positionSchemaId
        self.schema = schema
        self.data = data
    }

    /// Convert to new position data for API request (generated type)
    public var asNewPositionData: Components.Schemas.NewPositionDataSchema {
        // Convert [String: AnyCodable] to [String: OpenAPIValueContainer]
        var convertedData: [String: OpenAPIValueContainer] = [:]
        for (key, value) in data {
            if let jsonValue = try? JSONEncoder().encode(value),
               let container = try? JSONDecoder().decode(OpenAPIValueContainer.self, from: jsonValue)
            {
                convertedData[key] = container
            }
        }

        return Components.Schemas.NewPositionDataSchema(
            positionSchemaId: positionSchemaId,
            data: .init(additionalProperties: convertedData)
        )
    }
}

// MARK: - Pending Content

/// Content waiting to be created with an item
public struct PendingContent: Identifiable, Sendable {
    public let id: UUID
    public let type: ContentType
    public let formData: [String: AnyCodable]

    public init(
        id: UUID = UUID(),
        type: ContentType,
        formData: [String: AnyCodable]
    ) {
        self.id = id
        self.type = type
        self.formData = formData
    }

    /// Convert to content request for API
    public var asContentRequest: ContentRequest {
        let contentData = ContentData(
            title: formData["title"]?.value as? String,
            description: formData["description"]?.value as? String,
            mimeType: formData["mime_type"]?.value as? String,
            size: formData["size"]?.value as? Int,
            filePath: formData["file_path"]?.value as? String,
            previewImageUrl: formData["preview_image_url"]?.value as? String,
            videoLength: formData["video_length"]?.value as? Int,
            previewVideoUrl: formData["preview_video_url"]?.value as? String
        )
        return ContentRequest(type: type, data: contentData)
    }
}

// MARK: - Content Request

/// Request to create/update content
public struct ContentRequest: Codable, Sendable {
    public let type: ContentType
    public let data: ContentData

    public init(type: ContentType, data: ContentData) {
        self.type = type
        self.data = data
    }
}

/// Data payload for content
public struct ContentData: Codable, Sendable {
    public let title: String?
    public let description: String?
    public let mimeType: String?
    public let size: Int?
    public let filePath: String?
    public let previewImageUrl: String?
    public let videoLength: Int?
    public let previewVideoUrl: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil,
        filePath: String? = nil,
        previewImageUrl: String? = nil,
        videoLength: Int? = nil,
        previewVideoUrl: String? = nil
    ) {
        self.title = title
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.filePath = filePath
        self.previewImageUrl = previewImageUrl
        self.videoLength = videoLength
        self.previewVideoUrl = previewVideoUrl
    }

    /// Formatted file size string
    public var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Formatted video length string
    public var formattedVideoLength: String? {
        guard let videoLength = videoLength else { return nil }
        let minutes = videoLength / 60
        let seconds = videoLength % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
