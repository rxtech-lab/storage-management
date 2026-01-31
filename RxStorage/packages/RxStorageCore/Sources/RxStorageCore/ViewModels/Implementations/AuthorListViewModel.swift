//
//  AuthorListViewModel.swift
//  RxStorageCore
//
//  Author list view model implementation
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

        // If empty, fetch all authors
        if trimmedQuery.isEmpty {
            await fetchAuthors()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = AuthorFilters(search: trimmedQuery, limit: 10)
            authors = try await authorService.fetchAuthors(filters: filters)
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

        do {
            authors = try await authorService.fetchAuthors(filters: nil)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
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
