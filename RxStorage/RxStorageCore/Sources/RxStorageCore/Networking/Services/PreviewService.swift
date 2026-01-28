//
//  PreviewService.swift
//  RxStorageCore
//
//  API service for item preview operations (used by App Clips)
//

import Foundation

/// Protocol for preview service operations
public protocol PreviewServiceProtocol {
    func fetchItemPreview(id: Int) async throws -> ItemPreview
}

/// Preview service implementation
public class PreviewService: PreviewServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Fetch item preview (works for both public and private items)
    /// - For public items: No authentication required
    /// - For private items: Requires authentication + whitelist access
    public func fetchItemPreview(id: Int) async throws -> ItemPreview {
        return try await apiClient.get(
            .getItemPreview(id: id),
            responseType: ItemPreview.self
        )
    }
}
