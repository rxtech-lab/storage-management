import Foundation
import Logging
import OpenAPIRuntime

public protocol ContentPreviewUploadServiceProtocol: Sendable {
    func getUploadTargets(itemId: String, items: [ContentPreviewUploadRequestItem]) async throws -> [ContentPreviewUploadTarget]
    func uploadToPresignedURL(
        uploadURL: String,
        fileURL: URL,
        contentType: String,
        onProgress: UploadProgressHandler?
    ) async throws
}

public enum ContentPreviewUploadServiceError: LocalizedError, Sendable {
    case invalidUploadURL
    case uploadFailed(statusCode: Int)
    case badRequest(String)
    case unauthorized
    case forbidden
    case notFound
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUploadURL:
            return "Invalid upload URL"
        case let .uploadFailed(statusCode):
            return "Upload failed with HTTP \(statusCode)"
        case let .badRequest(message):
            return message
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not found"
        case let .serverError(message):
            return message
        }
    }
}

public struct ContentPreviewUploadService: ContentPreviewUploadServiceProtocol {
    private let logger = Logger(label: "ContentPreviewUploadService")

    public init() {}

    static func makeRequestBody(
        itemId: String,
        items: [ContentPreviewUploadRequestItem]
    ) -> Components.Schemas.ContentPreviewUploadRequestSchema {
        let payloads = items.map { item in
            Components.Schemas.ContentPreviewUploadItemSchema(
                filename: item.filename,
                _type: item.mediaType == .video ? .video : .image,
                title: item.title,
                description: item.description,
                mime_type: item.mimeType,
                size: item.size,
                file_path: item.filePath,
                video_length: item.videoLength
            )
        }

        return .init(item_id: itemId, items: payloads)
    }

    public func getUploadTargets(itemId: String, items: [ContentPreviewUploadRequestItem]) async throws -> [ContentPreviewUploadTarget] {
        let requestBody = Self.makeRequestBody(itemId: itemId, items: items)
        let response = try await StorageAPIClient.shared.client.getContentPreviewUploadUrls(
            .init(body: .json(requestBody))
        )

        switch response {
        case let .created(created):
            let body = try created.body.json
            return body.map {
                ContentPreviewUploadTarget(
                    id: $0.id,
                    imageURL: $0.imageUrl,
                    videoURL: $0.videoUrl
                )
            }
        case let .badRequest(badRequest):
            let error = try? badRequest.body.json
            throw ContentPreviewUploadServiceError.badRequest(error?.error ?? "Bad request")
        case .unauthorized:
            throw ContentPreviewUploadServiceError.unauthorized
        case .forbidden:
            throw ContentPreviewUploadServiceError.forbidden
        case .notFound:
            throw ContentPreviewUploadServiceError.notFound
        case .internalServerError:
            throw ContentPreviewUploadServiceError.serverError("Internal server error")
        case let .undocumented(statusCode, _):
            throw ContentPreviewUploadServiceError.serverError("HTTP \(statusCode)")
        }
    }

    public func uploadToPresignedURL(
        uploadURL: String,
        fileURL: URL,
        contentType: String,
        onProgress: UploadProgressHandler? = nil
    ) async throws {
        guard let url = URL(string: uploadURL) else {
            throw ContentPreviewUploadServiceError.invalidUploadURL
        }

        onProgress?(0, 1)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let fileSize = attributes?[.size] as? NSNumber {
            request.setValue(fileSize.stringValue, forHTTPHeaderField: "Content-Length")
        }

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContentPreviewUploadServiceError.serverError("Invalid response")
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            logger.error("Presigned upload failed", metadata: ["status": "\(httpResponse.statusCode)"])
            throw ContentPreviewUploadServiceError.uploadFailed(statusCode: httpResponse.statusCode)
        }

        onProgress?(1, 1)
    }
}
