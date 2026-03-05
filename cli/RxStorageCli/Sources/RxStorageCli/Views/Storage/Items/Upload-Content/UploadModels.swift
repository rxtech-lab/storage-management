import Foundation

enum UploadStep {
    case enterPath
    case enterExtensions
    case listFiles
    case uploadOptions
    case uploading
    case done
}

enum VideoUploadMode {
    case imageOnly
    case videoAndImage
}

struct FileEntry: Sendable {
    enum FileType: String, Sendable {
        case image
        case video
    }

    let path: String
    let filename: String
    let ext: String
    let mimeType: String
    let type: FileType
    let size: Int
}

struct UploadResult: Sendable {
    let filename: String
    let success: Bool
    let error: String?
}

struct ContentPreviewUploadItem: Sendable {
    let filename: String
    let type: FileEntry.FileType
    let title: String
    let mimeType: String
    let size: Int
    let filePath: String
    let videoLength: Double?
}
