//
//  ItemPreviewViewModel.swift
//  RxStorageCore
//
//  Item preview view model implementation for App Clips
//

import Foundation
import Observation

/// Item preview view model implementation
@Observable
@MainActor
public final class ItemPreviewViewModel: ItemPreviewViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var preview: ItemPreview?
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public private(set) var requiresAuthentication = false

    // MARK: - Dependencies

    private let previewService: PreviewServiceProtocol

    // MARK: - Initialization

    public init(previewService: PreviewServiceProtocol = PreviewService()) {
        self.previewService = previewService
    }

    // MARK: - Public Methods

    public func fetchPreview(id: Int) async {
        isLoading = true
        error = nil
        requiresAuthentication = false

        do {
            preview = try await previewService.fetchItemPreview(id: id)
            isLoading = false
        } catch let apiError as APIError {
            // Handle specific error cases
            switch apiError {
            case .unauthorized:
                // Private item requires authentication
                requiresAuthentication = true
                self.error = PreviewError.authenticationRequired
            case .forbidden:
                // User authenticated but not whitelisted
                self.error = PreviewError.accessDenied
            case .notFound:
                self.error = PreviewError.itemNotFound
            default:
                self.error = apiError
            }
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

// MARK: - Preview Errors

public enum PreviewError: LocalizedError {
    case authenticationRequired
    case accessDenied
    case itemNotFound

    public var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "This item is private. Please sign in to view it."
        case .accessDenied:
            return "You don't have permission to view this item."
        case .itemNotFound:
            return "Item not found."
        }
    }
}
