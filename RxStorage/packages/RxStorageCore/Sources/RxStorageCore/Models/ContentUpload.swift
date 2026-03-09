import Foundation

public enum ContentUploadVideoMode: String, CaseIterable, Sendable {
    case imageOnly
    case videoAndImage

    public var displayName: String {
        switch self {
        case .imageOnly:
            return "Thumbnails Only"
        case .videoAndImage:
            return "Video + Thumbnails"
        }
    }
}

public enum ContentUploadSessionStatus: String, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
    case stopped

    public var isTerminal: Bool {
        self == .completed || self == .stopped
    }
}

public enum ContentUploadMediaType: String, Sendable {
    case image
    case video
}

public enum ContentUploadFileStatus: Sendable, Equatable {
    case pending
    case preprocessing
    case requestingUploadURL(attempt: Int)
    case uploadingThumbnail(attempt: Int)
    case uploadingVideo(attempt: Int)
    case cancelled
    case succeeded
    case failed(String)

    public var isInProgress: Bool {
        switch self {
        case .preprocessing, .requestingUploadURL, .uploadingThumbnail, .uploadingVideo:
            return true
        case .pending, .cancelled, .succeeded, .failed:
            return false
        }
    }

    public var isFinished: Bool {
        switch self {
        case .succeeded, .failed, .cancelled:
            return true
        case .pending, .preprocessing, .requestingUploadURL, .uploadingThumbnail, .uploadingVideo:
            return false
        }
    }

    public var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .preprocessing:
            return "Processing"
        case let .requestingUploadURL(attempt):
            return "Requesting URLs (attempt \(attempt))"
        case let .uploadingThumbnail(attempt):
            return "Uploading thumbnail (attempt \(attempt))"
        case let .uploadingVideo(attempt):
            return "Uploading video (attempt \(attempt))"
        case .cancelled:
            return "Cancelled"
        case .succeeded:
            return "Succeeded"
        case let .failed(message):
            return "Failed: \(message)"
        }
    }
}

public struct ContentUploadInputFile: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let fileURL: URL
    public let filename: String
    public let relativePath: String
    public let extensionName: String
    public let mimeType: String
    public let mediaType: ContentUploadMediaType
    public let fileSize: Int64

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        filename: String,
        relativePath: String,
        extensionName: String,
        mimeType: String,
        mediaType: ContentUploadMediaType,
        fileSize: Int64
    ) {
        self.id = id
        self.fileURL = fileURL
        self.filename = filename
        self.relativePath = relativePath
        self.extensionName = extensionName
        self.mimeType = mimeType
        self.mediaType = mediaType
        self.fileSize = fileSize
    }
}

public struct ContentUploadFileProgress: Identifiable, Sendable {
    public let id: UUID
    public let inputFile: ContentUploadInputFile
    public var status: ContentUploadFileStatus
    public var progress: Double
    public var attemptsUsed: Int
    public var errorMessage: String?
    public var logMessage: String?
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(
        inputFile: ContentUploadInputFile,
        status: ContentUploadFileStatus = .pending,
        progress: Double = 0,
        attemptsUsed: Int = 0,
        errorMessage: String? = nil,
        logMessage: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        id = inputFile.id
        self.inputFile = inputFile
        self.status = status
        self.progress = progress
        self.attemptsUsed = attemptsUsed
        self.errorMessage = errorMessage
        self.logMessage = logMessage
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct ContentUploadSession: Identifiable, Sendable {
    public let id: UUID
    public let itemId: String
    public let itemTitle: String
    public var status: ContentUploadSessionStatus
    public var videoMode: ContentUploadVideoMode?
    public var files: [ContentUploadFileProgress]
    public let createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var lastErrorMessage: String?

    public init(
        id: UUID = UUID(),
        itemId: String,
        itemTitle: String,
        status: ContentUploadSessionStatus = .idle,
        videoMode: ContentUploadVideoMode? = nil,
        files: [ContentUploadFileProgress],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.itemTitle = itemTitle
        self.status = status
        self.videoMode = videoMode
        self.files = files
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.lastErrorMessage = lastErrorMessage
    }

    public var totalCount: Int {
        files.count
    }

    public var hasVideoFiles: Bool {
        files.contains { $0.inputFile.mediaType == .video }
    }

    public var succeededCount: Int {
        files.filter { $0.status == .succeeded }.count
    }

    public var failedCount: Int {
        files.filter {
            if case .failed = $0.status {
                return true
            }
            return false
        }.count
    }

    public var cancelledCount: Int {
        files.filter { $0.status == .cancelled }.count
    }

    public var completedCount: Int {
        files.filter { $0.status.isFinished }.count
    }

    public var overallProgress: Double {
        guard !files.isEmpty else { return 0 }
        let total = files.reduce(0.0) { partial, file in
            switch file.status {
            case .succeeded, .failed, .cancelled:
                return partial + 1
            case .pending:
                return partial
            default:
                return partial + max(0, min(file.progress, 0.99))
            }
        }
        return total / Double(files.count)
    }
}

public struct ContentPreviewUploadRequestItem: Sendable {
    public let filename: String
    public let mediaType: ContentUploadMediaType
    public let title: String
    public let description: String?
    public let mimeType: String
    public let size: Int
    public let filePath: String
    public let videoLength: Double?

    public init(
        filename: String,
        mediaType: ContentUploadMediaType,
        title: String,
        description: String? = nil,
        mimeType: String,
        size: Int,
        filePath: String,
        videoLength: Double? = nil
    ) {
        self.filename = filename
        self.mediaType = mediaType
        self.title = title
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.filePath = filePath
        self.videoLength = videoLength
    }
}

public struct ContentPreviewUploadTarget: Sendable, Equatable {
    public let id: String
    public let imageURL: String
    public let videoURL: String?

    public init(id: String, imageURL: String, videoURL: String?) {
        self.id = id
        self.imageURL = imageURL
        self.videoURL = videoURL
    }
}

public struct ContentUploadPreparedAsset: Sendable {
    public let thumbnailURL: URL
    public let uploadVideoURL: URL?
    public let videoLength: Double?

    public init(thumbnailURL: URL, uploadVideoURL: URL?, videoLength: Double?) {
        self.thumbnailURL = thumbnailURL
        self.uploadVideoURL = uploadVideoURL
        self.videoLength = videoLength
    }
}

public enum ContentUploadCatalog {
    public static let defaultFolderExtensionInput = "jpg,jpeg,png,webp,heic,mp4,mov,mkv,avi,webm"

    public static func mediaType(forExtension ext: String) -> ContentUploadMediaType? {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff", "tif":
            return .image
        case "mp4", "mov", "avi", "mkv", "webm":
            return .video
        default:
            return nil
        }
    }

    public static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "bmp": return "image/bmp"
        case "tiff", "tif": return "image/tiff"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }

    public static func parseExtensionList(_ raw: String) -> Set<String> {
        Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
}
