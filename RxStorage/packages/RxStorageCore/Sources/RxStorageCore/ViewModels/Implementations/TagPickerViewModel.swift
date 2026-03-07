//
//  TagPickerViewModel.swift
//  RxStorageCore
//
//  Tag picker view model with search and pagination
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Tag picker view model for searchable selection
@Observable
@MainActor
public final class TagPickerViewModel {
    // MARK: - Published Properties

    public private(set) var tags: [Tag] = []
    public private(set) var searchResults: [Tag] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    public var searchText = ""

    /// IDs of tags already assigned to the current item
    public var existingTagIds: Set<String> = []

    // MARK: - Private Properties

    private var nextCursor: String?
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let tagService: TagServiceProtocol
    private let logger = Logger(label: "com.rxlab.rxstorage.TagPickerViewModel")

    // MARK: - Initialization

    public init(tagService: TagServiceProtocol = TagService()) {
        self.tagService = tagService
        setupSearchPipeline()
    }

    // MARK: - Private Methods

    private func setupSearchPipeline() {
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                Task { @MainActor in
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        nextCursor = nil
        hasNextPage = true

        if trimmedQuery.isEmpty {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        do {
            let filters = TagFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await tagService.fetchTagsPaginated(filters: filters)
            searchResults = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Tag search failed: \(error.localizedDescription)")
        }

        isSearching = false
    }

    // MARK: - Public Methods

    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func loadTags() async {
        isLoading = true
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = TagFilters(limit: PaginationDefaults.pageSize)
            let response = try await tagService.fetchTagsPaginated(filters: filters)
            tags = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load tags: \(error.localizedDescription)")
        }

        isLoading = false
    }

    public func loadMore() async {
        guard !isLoadingMore, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = TagFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await tagService.fetchTagsPaginated(filters: filters)

            if searchText.isEmpty {
                let existingIds = Set(tags.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                tags.append(contentsOf: newItems)
            } else {
                let existingIds = Set(searchResults.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                searchResults.append(contentsOf: newItems)
            }

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load more tags: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Get the current list of items to display
    public var displayItems: [Tag] {
        searchText.isEmpty ? tags : searchResults
    }

    /// Tags available to add (not already assigned to item)
    public var availableTags: [Tag] {
        displayItems.filter { !existingTagIds.contains($0.id) }
    }

    /// Check if should load more for a given item
    public func shouldLoadMore(for tag: Tag) -> Bool {
        let items = displayItems
        guard let index = items.firstIndex(where: { $0.id == tag.id }) else {
            return false
        }
        let threshold = 3
        return index >= items.count - threshold && hasNextPage && !isLoadingMore && !isLoading
    }
}
