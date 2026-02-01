//
//  ParentItemPickerViewModel.swift
//  RxStorageCore
//
//  Parent item picker view model with search and pagination
//

@preconcurrency import Combine
import Foundation
import Observation

/// Parent item picker view model for searchable selection
@Observable
@MainActor
public final class ParentItemPickerViewModel {
    // MARK: - Published Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var searchResults: [StorageItem] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    public var searchText = ""

    // MARK: - Private Properties

    private var nextCursor: String?
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// The current item ID to exclude from the list (can't be its own parent)
    private let excludeItemId: Int?

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol

    // MARK: - Initialization

    public init(excludeItemId: Int? = nil, itemService: ItemServiceProtocol = ItemService()) {
        self.excludeItemId = excludeItemId
        self.itemService = itemService
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

    private func filterExcluded(_ items: [StorageItem]) -> [StorageItem] {
        guard let excludeId = excludeItemId else { return items }
        return items.filter { $0.id != excludeId }
    }

    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        // Reset pagination
        nextCursor = nil
        hasNextPage = true

        if trimmedQuery.isEmpty {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        do {
            let filters = ItemFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await itemService.fetchItemsPaginated(filters: filters)
            searchResults = filterExcluded(response.data)
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            // Silent fail for search
        }

        isSearching = false
    }

    // MARK: - Public Methods

    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func loadItems() async {
        isLoading = true
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = ItemFilters(limit: PaginationDefaults.pageSize)
            let response = try await itemService.fetchItemsPaginated(filters: filters)
            items = filterExcluded(response.data)
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            // Silent fail
        }

        isLoading = false
    }

    public func loadMore() async {
        guard !isLoadingMore, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = ItemFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await itemService.fetchItemsPaginated(filters: filters)
            let filteredItems = filterExcluded(response.data)

            if searchText.isEmpty {
                let existingIds = Set(items.map { $0.id })
                let newItems = filteredItems.filter { !existingIds.contains($0.id) }
                items.append(contentsOf: newItems)
            } else {
                let existingIds = Set(searchResults.map { $0.id })
                let newItems = filteredItems.filter { !existingIds.contains($0.id) }
                searchResults.append(contentsOf: newItems)
            }

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            // Silent fail
        }

        isLoadingMore = false
    }

    /// Get the current list of items to display
    public var displayItems: [StorageItem] {
        searchText.isEmpty ? items : searchResults
    }

    /// Check if should load more for a given item
    public func shouldLoadMore(for item: StorageItem) -> Bool {
        let currentItems = displayItems
        guard let index = currentItems.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        let threshold = 3
        return index >= currentItems.count - threshold && hasNextPage && !isLoadingMore && !isLoading
    }
}
