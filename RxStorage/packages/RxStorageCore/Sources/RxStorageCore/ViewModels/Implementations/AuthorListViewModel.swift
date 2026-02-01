//
//  AuthorListViewModel.swift
//  RxStorageCore
//
//  Author list view model implementation with pagination support
//

@preconcurrency import Combine
import Foundation
import Observation

/// Author list view model implementation
@Observable
@MainActor
public final class AuthorListViewModel: AuthorListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var authors: [Author] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Pagination State

    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    private var nextCursor: String?

    // MARK: - Combine

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol

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

        // Reset pagination state for new search
        nextCursor = nil
        hasNextPage = true

        // If empty, fetch all authors
        if trimmedQuery.isEmpty {
            await fetchAuthors()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = AuthorFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await authorService.fetchAuthorsPaginated(filters: filters)
            authors = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isSearching = false
        } catch {
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

    public func fetchAuthors() async {
        isLoading = true
        error = nil

        // Reset pagination state
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = AuthorFilters(limit: PaginationDefaults.pageSize)
            let response = try await authorService.fetchAuthorsPaginated(filters: filters)
            authors = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func loadMoreAuthors() async {
        guard !isLoadingMore, !isLoading, !isSearching, hasNextPage, let cursor = nextCursor else {
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

            // Append new authors (avoid duplicates)
            let existingIds = Set(authors.map { $0.id })
            let newAuthors = response.data.filter { !existingIds.contains($0.id) }
            authors.append(contentsOf: newAuthors)

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoadingMore = false
        } catch {
            self.error = error
            isLoadingMore = false
        }
    }

    public func refreshAuthors() async {
        if searchText.isEmpty {
            await fetchAuthors()
        } else {
            await performSearch(query: searchText)
        }
    }

    public func deleteAuthor(_ author: Author) async throws {
        try await authorService.deleteAuthor(id: author.id)

        // Remove from local list
        authors.removeAll { $0.id == author.id }
    }
}
