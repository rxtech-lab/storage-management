//
//  AuthorListViewModel.swift
//  RxStorageCore
//
//  Author list view model implementation
//

import Foundation
import Observation

/// Author list view model implementation
@Observable
@MainActor
public final class AuthorListViewModel: AuthorListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var authors: [Author] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol

    // MARK: - Computed Properties

    public var filteredAuthors: [Author] {
        guard !searchText.isEmpty else { return authors }
        return authors.filter { author in
            author.name.localizedCaseInsensitiveContains(searchText) ||
            (author.bio?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Initialization

    public init(authorService: AuthorServiceProtocol = AuthorService()) {
        self.authorService = authorService
    }

    // MARK: - Public Methods

    public func fetchAuthors() async {
        isLoading = true
        error = nil

        do {
            authors = try await authorService.fetchAuthors()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshAuthors() async {
        await fetchAuthors()
    }

    public func deleteAuthor(_ author: Author) async throws {
        try await authorService.deleteAuthor(id: author.id)

        // Remove from local list
        authors.removeAll { $0.id == author.id }
    }
}
