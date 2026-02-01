//
//  AuthorPickerViewModel.swift
//  RxStorageCore
//
//  Author picker view model with search and pagination
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Author picker view model for searchable selection
@Observable
@MainActor
public final class AuthorPickerViewModel {
    // MARK: - Published Properties

    public private(set) var authors: [Author] = []
    public private(set) var searchResults: [Author] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    public var searchText = ""

    // MARK: - Private Properties

    private var nextCursor: String?
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol
    private let logger = Logger(label: "com.rxlab.rxstorage.AuthorPickerViewModel")

    // MARK: - Initialization

    public init(authorService: AuthorServiceProtocol = AuthorService()) {
        self.authorService = authorService
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
            let filters = AuthorFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await authorService.fetchAuthorsPaginated(filters: filters)
            searchResults = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Author search failed: \(error.localizedDescription)")
        }

        isSearching = false
    }

    // MARK: - Public Methods

    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func loadAuthors() async {
        isLoading = true
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = AuthorFilters(limit: PaginationDefaults.pageSize)
            let response = try await authorService.fetchAuthorsPaginated(filters: filters)
            authors = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load authors: \(error.localizedDescription)")
        }

        isLoading = false
    }

    public func loadMore() async {
        guard !isLoadingMore, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = AuthorFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await authorService.fetchAuthorsPaginated(filters: filters)

            if searchText.isEmpty {
                let existingIds = Set(authors.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                authors.append(contentsOf: newItems)
            } else {
                let existingIds = Set(searchResults.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                searchResults.append(contentsOf: newItems)
            }

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load more authors: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Get the current list of items to display
    public var displayItems: [Author] {
        searchText.isEmpty ? authors : searchResults
    }

    /// Check if should load more for a given item
    public func shouldLoadMore(for author: Author) -> Bool {
        let items = displayItems
        guard let index = items.firstIndex(where: { $0.id == author.id }) else {
            return false
        }
        let threshold = 3
        return index >= items.count - threshold && hasNextPage && !isLoadingMore && !isLoading
    }
}
