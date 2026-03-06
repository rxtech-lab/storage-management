//
//  ContentListViewModel.swift
//  RxStorageCore
//
//  View model for paginated content list with search
//

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.rxlab.rxstorage", category: "ContentListViewModel")

/// View model for browsing all contents of an item with pagination and search
@Observable
@MainActor
public final class ContentListViewModel {
    // MARK: - Published Properties

    public private(set) var contents: [Content] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var hasMore = false
    public private(set) var error: Error?

    private var nextCursor: String?
    private var currentItemId: String?
    private var currentSearch: String?

    // MARK: - Dependencies

    private let contentService: ContentServiceProtocol

    // MARK: - Initialization

    public init(contentService: ContentServiceProtocol = ContentService()) {
        self.contentService = contentService
    }

    // MARK: - Public Methods

    /// Fetch initial page of contents
    public func fetchContents(itemId: String, search: String? = nil) async {
        currentItemId = itemId
        currentSearch = search
        isLoading = true
        error = nil

        do {
            let result = try await contentService.fetchItemContentsPaginated(
                itemId: itemId,
                cursor: nil,
                search: search,
                limit: 20
            )
            contents = result.data
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            logger.error("Failed to fetch contents: \(error.localizedDescription, privacy: .public)")
            self.error = error
        }

        isLoading = false
    }

    /// Load next page of contents
    public func loadMore() async {
        guard let itemId = currentItemId, let cursor = nextCursor, !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let result = try await contentService.fetchItemContentsPaginated(
                itemId: itemId,
                cursor: cursor,
                search: currentSearch,
                limit: 20
            )
            contents.append(contentsOf: result.data)
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            logger.error("Failed to load more contents: \(error.localizedDescription, privacy: .public)")
        }

        isLoadingMore = false
    }
}
