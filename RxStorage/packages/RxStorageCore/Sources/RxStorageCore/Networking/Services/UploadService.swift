//
//  UploadService.swift
//  RxStorageCore
//
//  API service for file upload operations
//

import Foundation

/// Protocol for upload service operations
public protocol UploadServiceProtocol: Sendable {
    /// Get a presigned URL for uploading a file
    /// - Parameters:
    ///   - filename: Original filename
    ///   - contentType: MIME type of the file
    ///   - size: Optional file size in bytes
    /// - Returns: Presigned URL response with upload URL and file ID
    func getPresignedURL(
        filename: String,
        contentType: String,
        size: Int?
    ) async throws -> PresignedURLResponse
}

/// Upload service implementation
public final class UploadService: UploadServiceProtocol, Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func getPresignedURL(
        filename: String,
        contentType: String,
        size: Int?
    ) async throws -> PresignedURLResponse {
        let request = PresignedURLRequest(
            filename: filename,
            contentType: contentType,
            size: size
        )

        return try await apiClient.post(
            .getPresignedURL,
            body: request,
            responseType: PresignedURLResponse.self
        )
    }
}
