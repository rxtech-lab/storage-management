//
//  ItemListViewModel.swift
//  RxStorageCore
//
//  Item list view model implementation with pagination support
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Item list view model implementation
@Observable
@MainActor
public final class ItemListViewModel: ItemListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var error: Error?
    public var filters = ItemFilters()
    public var searchText = ""

    // MARK: - Pagination State

    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    private var nextCursor: String?

    // MARK: - Combine

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol
    private let eventViewModel: EventViewModel?
    private let logger = Logger(label: "com.rxlab.rxstorage.ItemListViewModel")
    @ObservationIgnored private nonisolated(unsafe) var eventTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        itemService: ItemServiceProtocol = ItemService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.itemService = itemService
        self.eventViewModel = eventViewModel
        setupSearchPipeline()
        setupEventSubscription()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Event Subscription

    private func setupEventSubscription() {
        guard let eventViewModel else { return }

        eventTask = Task { [weak self] in
            for await event in eventViewModel.stream {
                guard let self else { break }
                await self.handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: AppEvent) async {
        switch event {
        case .itemCreated, .itemUpdated, .itemDeleted:
            await refreshItems()
        default:
            break
        }
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

        // Update filters with search query
        if trimmedQuery.isEmpty {
            filters.search = nil
        } else {
            filters.search = trimmedQuery
        }

        // Reset pagination state for new search
        nextCursor = nil
        hasNextPage = true

        isSearching = true
        error = nil

        do {
            var paginatedFilters = filters.isEmpty ? ItemFilters() : filters
            paginatedFilters.limit = PaginationDefaults.pageSize

            let response = try await itemService.fetchItemsPaginated(filters: paginatedFilters)
            items = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isSearching = false
        } catch is CancellationError {
            isSearching = false
        } catch let apiError as APIError where apiError.isCancellation {
            isSearching = false
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            isSearching = false
        } catch {
            logger.error("Failed to search items: \(error.localizedDescription)", metadata: [
                "error": "\(error)",
            ])
            self.error = error
            isSearching = false
        }
    }

    // MARK: - Public Methods

    /// Trigger a search with the given query (debounced)
    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func fetchItems() async {
        isLoading = true
        error = nil

        // Reset pagination state
        nextCursor = nil
        hasNextPage = true

        do {
            var paginatedFilters = filters.isEmpty ? ItemFilters() : filters
            paginatedFilters.limit = PaginationDefaults.pageSize

            let response = try await itemService.fetchItemsPaginated(filters: paginatedFilters)
            items = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoading = false
        } catch is CancellationError {
            // Task was cancelled (e.g., view dismissed) - ignore silently
            isLoading = false
        } catch let apiError as APIError where apiError.isCancellation {
            // Wrapped network cancellation - ignore silently
            isLoading = false
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Network request was cancelled - ignore silently
            isLoading = false
        } catch {
            logger.error("Failed to fetch items: \(error.localizedDescription)", metadata: [
                "error": "\(error)",
            ])
            self.error = error
            isLoading = false
        }
    }

    public func loadMoreItems() async {
        // Guard conditions
        guard !isLoadingMore, !isLoading, !isSearching, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var paginatedFilters = filters.isEmpty ? ItemFilters() : filters
            paginatedFilters.cursor = cursor
            paginatedFilters.direction = .next
            paginatedFilters.limit = PaginationDefaults.pageSize

            let response = try await itemService.fetchItemsPaginated(filters: paginatedFilters)

            // Append new items (avoid duplicates)
            let existingIds = Set(items.map { $0.id })
            let newItems = response.data.filter { !existingIds.contains($0.id) }
            items.append(contentsOf: newItems)

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoadingMore = false
        } catch is CancellationError {
            isLoadingMore = false
        } catch let apiError as APIError where apiError.isCancellation {
            isLoadingMore = false
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            isLoadingMore = false
        } catch {
            logger.error("Failed to load more items: \(error.localizedDescription)", metadata: [
                "error": "\(error)",
            ])
            self.error = error
            isLoadingMore = false
        }
    }

    public func refreshItems() async {
        if searchText.isEmpty {
            await fetchItems()
        } else {
            await performSearch(query: searchText)
        }
    }

    @discardableResult
    public func deleteItem(_ item: StorageItem) async throws -> Int {
        let itemId = item.id
        try await itemService.deleteItem(id: itemId)

        // Remove from local list
        items.removeAll { $0.id == itemId }

        // Emit event
        eventViewModel?.emit(.itemDeleted(id: itemId))

        return itemId
    }

    public func clearFilters() {
        filters = ItemFilters()
        searchText = ""
        // Reset pagination
        nextCursor = nil
        hasNextPage = true
    }

    public func applyFilters(_ filters: ItemFilters) {
        self.filters = filters
        if let search = filters.search {
            searchText = search
        }
        // Reset pagination when filters change
        nextCursor = nil
        hasNextPage = true
    }

    public func clearError() {
        error = nil
    }
}

// MARK: - ItemFilters Extension

extension ItemFilters {
    /// Check if filters are empty
    var isEmpty: Bool {
        categoryId == nil &&
            locationId == nil &&
            authorId == nil &&
            parentId == nil &&
            visibility == nil &&
            search == nil
    }

    /// Check if there are active filters (excluding search)
    public var hasActiveFilters: Bool {
        categoryId != nil ||
            locationId != nil ||
            authorId != nil ||
            parentId != nil ||
            visibility != nil
    }
}
