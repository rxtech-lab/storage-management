//
//  AuthorDetailViewModel.swift
//  RxStorage
//
//  Author detail view model for displaying author details
//

import Foundation
import Observation
import RxStorageCore

/// Author detail view model
@Observable
@MainActor
final class AuthorDetailViewModel {
    // MARK: - Properties

    private(set) var author: Author?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol

    // MARK: - Initialization

    init(authorService: AuthorServiceProtocol? = nil) {
        self.authorService = authorService ?? AuthorService()
    }

    // MARK: - Public Methods

    func fetchAuthor(id: Int) async {
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
