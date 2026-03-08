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

    // MARK: - Items Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var totalItems: Int = 0

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol

    // MARK: - Initialization

    public init(authorService: AuthorServiceProtocol? = nil) {
        self.authorService = authorService ?? AuthorService()
    }

    // MARK: - Public Methods

    public func fetchAuthor(id: String) async {
        isLoading = true
        error = nil

        do {
            let detail = try await authorService.fetchAuthorDetail(id: id)
            author = Author(id: detail.id, userId: detail.userId, name: detail.name, bio: detail.bio, createdAt: detail.createdAt, updatedAt: detail.updatedAt)
            items = detail.items
            totalItems = detail.totalItems
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
