//
//  ContentService.swift
//  RxStorageCore
//
//  Content service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "ContentService")

// MARK: - Protocol

/// Protocol for content service operations
public protocol ContentServiceProtocol: Sendable {
    func fetchItemContents(itemId: Int) async throws -> [Content]
    func createContent(itemId: Int, _ request: ContentRequest) async throws -> Content
    func updateContent(id: Int, _ request: ContentRequest) async throws -> Content
    func deleteContent(id: Int) async throws
}

// MARK: - Implementation

/// Content service implementation using generated OpenAPI client
public struct ContentService: ContentServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func fetchItemContents(itemId: Int) async throws -> [Content] {
        try await StorageAPIClient.shared.client.getItemContents(.init(path: .init(id: String(itemId))))
    }

    @APICall(.created)
    public func createContent(itemId: Int, _ request: ContentRequest) async throws -> Content {
        let contentData = request.data.toAPIData(for: request.type)
        let apiRequest = NewContentRequest(
            _type: Components.Schemas.ContentInsertSchema._typePayload(rawValue: request.type.rawValue)!,
            data: .init(value1: contentData)
        )

        try await StorageAPIClient.shared.client.createItemContent(.init(
            path: .init(id: String(itemId)),
            body: .json(apiRequest)
        ))
    }

    @APICall(.ok)
    public func updateContent(id: Int, _ request: ContentRequest) async throws -> Content {
        let contentData = request.data.toAPIData(for: request.type)
        let apiRequest = UpdateContentRequest(
            _type: Components.Schemas.ContentUpdateSchema._typePayload(rawValue: request.type.rawValue),
            data: .init(value1: contentData)
        )

        try await StorageAPIClient.shared.client.updateContent(.init(
            path: .init(id: String(id)),
            body: .json(apiRequest)
        ))
    }

    public func deleteContent(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deleteContent(.init(path: .init(id: String(id))))

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}

// MARK: - ContentData Extension

extension ContentData {
    /// Convert to API data format based on content type
    func toAPIData(for type: ContentType) -> Components.Schemas.ContentDataSchema {
        switch type {
        case .file:
            return .FileContentDataSchema(.init(
                title: title ?? "",
                description: description,
                mime_type: mimeType ?? "",
                size: Double(size ?? 0),
                file_path: filePath ?? ""
            ))
        case .image:
            return .ImageContentDataSchema(.init(
                title: title ?? "",
                description: description,
                mime_type: mimeType ?? "",
                size: Double(size ?? 0),
                file_path: filePath ?? "",
                preview_image_url: previewImageUrl
            ))
        case .video:
            return .VideoContentDataSchema(.init(
                title: title ?? "",
                description: description,
                mime_type: mimeType ?? "",
                size: Double(size ?? 0),
                file_path: filePath ?? "",
                preview_image_url: previewImageUrl,
                video_length: Double(videoLength ?? 0),
                preview_video_url: previewVideoUrl
            ))
        }
    }
}
