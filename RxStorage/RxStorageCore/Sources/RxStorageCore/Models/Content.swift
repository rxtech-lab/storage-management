//
//  Content.swift
//  RxStorageCore
//
//  Content (file/image/video) model matching API schema
//

import Foundation

/// Content attached to an item (file, image, or video)
public struct Content: Codable, Identifiable, Hashable {
    public let id: Int
    public let itemId: Int
    public let type: ContentType
    public let data: ContentData
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: Int,
        itemId: Int,
        type: ContentType,
        data: ContentData,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.itemId = itemId
        self.type = type
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Content type
    public enum ContentType: String, Codable, CaseIterable {
        case file = "file"
        case image = "image"
        case video = "video"

        public var displayName: String {
            switch self {
            case .file: return "File"
            case .image: return "Image"
            case .video: return "Video"
            }
        }

        public var icon: String {
            switch self {
            case .file: return "doc.fill"
            case .image: return "photo.fill"
            case .video: return "video.fill"
            }
        }
    }
}

/// Content data with polymorphic structure based on type
public struct ContentData: Codable, Hashable {
    public let title: String?
    public let description: String?
    public let mimeType: String?
    public let size: Int?
    public let filePath: String?

    // Image-specific
    public let previewImageUrl: String?

    // Video-specific
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

    /// Format file size for display
    public var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Format video length for display (e.g., "2:35")
    public var formattedVideoLength: String? {
        guard let videoLength = videoLength else { return nil }
        let minutes = videoLength / 60
        let seconds = videoLength % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Request body for creating/updating content
public struct ContentRequest: Codable {
    public let type: Content.ContentType
    public let data: ContentData

    public init(type: Content.ContentType, data: ContentData) {
        self.type = type
        self.data = data
    }
}
