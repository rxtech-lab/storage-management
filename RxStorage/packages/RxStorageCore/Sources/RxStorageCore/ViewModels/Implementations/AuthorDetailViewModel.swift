//
//  AuthorDetailViewModel.swift
//  RxStorage
//
//  Author detail view model for displaying author details
//

import Foundation
import Observation

/// Author detail view model
@Observable
@MainActor
public final class AuthorDetailViewModel {
    // MARK: - Properties

    public private(set) var author: Author?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol

    // MARK: - Initialization

    public init(authorService: AuthorServiceProtocol? = nil) {
        self.authorService = authorService ?? AuthorService()
    }

    // MARK: - Public Methods

    public func fetchAuthor(id: Int) async {
        isLoading = true
        error = nil

        do {
            author = try await authorService.fetchAuthor(id: id)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refresh() async {
        guard let authorId = author?.id else { return }
        await fetchAuthor(id: authorId)
    }

    func clearError() {
        error = nil
    }
}
