//
//  MockAuthorService.swift
//  RxStorageCoreTests
//
//  Mock author service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock author service for testing
@MainActor
public final class MockAuthorService: AuthorServiceProtocol {
    // MARK: - Properties

    public var fetchAuthorsResult: Result<[Author], Error> = .success([])
    public var fetchAuthorResult: Result<Author, Error>?
    public var createAuthorResult: Result<Author, Error>?
    public var updateAuthorResult: Result<Author, Error>?
    public var deleteAuthorResult: Result<Void, Error>?

    // Call tracking
    public var fetchAuthorsCalled = false
    public var fetchAuthorCalled = false
    public var lastFetchAuthorId: Int?
    public var createAuthorCalled = false
    public var updateAuthorCalled = false
    public var deleteAuthorCalled = false

    public var lastCreateAuthorRequest: NewAuthorRequest?
    public var lastUpdateAuthorId: Int?
    public var lastUpdateAuthorRequest: UpdateAuthorRequest?
    public var lastDeleteAuthorId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - AuthorServiceProtocol

    public func fetchAuthors(filters: AuthorFilters?) async throws -> [Author] {
        fetchAuthorsCalled = true
        switch fetchAuthorsResult {
        case .success(let authors):
            return authors
        case .failure(let error):
            throw error
        }
    }

    public func fetchAuthor(id: Int) async throws -> Author {
        fetchAuthorCalled = true
        lastFetchAuthorId = id

        if let result = fetchAuthorResult {
            switch result {
            case .success(let author):
                return author
            case .failure(let error):
                throw error
            }
        }

        throw APIError.notFound
    }

    public func createAuthor(_ request: NewAuthorRequest) async throws -> Author {
        createAuthorCalled = true
        lastCreateAuthorRequest = request

        if let result = createAuthorResult {
            switch result {
            case .success(let author):
                return author
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateAuthor(id: Int, _ request: UpdateAuthorRequest) async throws -> Author {
        updateAuthorCalled = true
        lastUpdateAuthorId = id
        lastUpdateAuthorRequest = request

        if let result = updateAuthorResult {
            switch result {
            case .success(let author):
                return author
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteAuthor(id: Int) async throws {
        deleteAuthorCalled = true
        lastDeleteAuthorId = id

        if let result = deleteAuthorResult {
            switch result {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        }
    }
}
