//
//  Upload.swift
//  RxStorageCore
//
//  Upload-related models for file upload with presigned URLs
//

import Foundation

// MARK: - Upload Error

/// Errors that can occur during file upload
public enum UploadError: LocalizedError, Sendable {
    case fileNotFound
    case invalidFileURL
    case fileTooLarge(maxSize: Int64)
    case invalidContentType
    case presignedURLFailed(String)
    case uploadFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .invalidFileURL:
            return "Invalid file URL"
        case let .fileTooLarge(maxSize):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB]
            formatter.countStyle = .file
            let maxSizeStr = formatter.string(fromByteCount: maxSize)
            return "File exceeds maximum size of \(maxSizeStr)"
        case .invalidContentType:
            return "Invalid content type. Only images are allowed."
        case let .presignedURLFailed(message):
            return "Failed to get upload URL: \(message)"
        case let .uploadFailed(message):
            return "Upload failed: \(message)"
        case .cancelled:
            return "Upload was cancelled"
        }
    }
}

// MARK: - Upload Result

/// Result of a successful upload
public struct UploadResult: Sendable {
    public let fileId: Int
    public let publicUrl: String
    public let key: String

    public init(fileId: Int, publicUrl: String, key: String) {
        self.fileId = fileId
        self.publicUrl = publicUrl
        self.key = key
    }

    /// Returns the file reference format used in item images array
    public var fileReference: String {
        "file:\(fileId)"
    }
}

// MARK: - Pending Upload

/// Represents an upload that is pending, in progress, or completed
public struct PendingUpload: Identifiable, Sendable {
    public let id: UUID
    public let localURL: URL
    public let filename: String
    public let contentType: String
    public let fileSize: Int64
    public var fileId: Int?
    public var publicUrl: String?
    public var progress: Double
    public var status: UploadStatus

    public init(
        id: UUID = UUID(),
        localURL: URL,
        filename: String,
        contentType: String,
        fileSize: Int64,
        fileId: Int? = nil,
        publicUrl: String? = nil,
        progress: Double = 0,
        status: UploadStatus = .pending
    ) {
        self.id = id
        self.localURL = localURL
        self.filename = filename
        self.contentType = contentType
        self.fileSize = fileSize
        self.fileId = fileId
        self.publicUrl = publicUrl
        self.progress = progress
        self.status = status
    }

    /// Returns "file:{fileId}" for use in item images array, or nil if not yet uploaded
    public var fileReference: String? {
        fileId.map { "file:\($0)" }
    }

    /// Format file size for display
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// Status of a pending upload
public enum UploadStatus: Sendable, Equatable {
    case pending
    case gettingPresignedURL
    case uploading
    case completed
    case failed(String)
    case cancelled

    public var isInProgress: Bool {
        switch self {
        case .pending, .gettingPresignedURL, .uploading:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - MIME Type Helper

/// Helper to determine MIME type from file extension
public enum MIMEType {
    public static func from(fileExtension ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        case "webp":
            return "image/webp"
        case "bmp":
            return "image/bmp"
        case "tiff", "tif":
            return "image/tiff"
        case "pdf":
            return "application/pdf"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        default:
            return "application/octet-stream"
        }
    }

    public static func from(url: URL) -> String {
        from(fileExtension: url.pathExtension)
    }

    public static func isImage(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("image/")
    }
}
