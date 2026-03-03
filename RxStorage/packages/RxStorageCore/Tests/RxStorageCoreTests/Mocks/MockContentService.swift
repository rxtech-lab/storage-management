//
//  MockContentService.swift
//  RxStorageCoreTests
//
//  Mock content service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock content service for testing
@MainActor
public final class MockContentService: ContentServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    public var fetchItemContentsResult: Result<[Content], Error> = .success([])
    public var createContentResult: Result<Content, Error>?
    public var updateContentResult: Result<Content, Error>?
    public var deleteContentResult: Result<Void, Error> = .success(())

    // Call tracking
    public var fetchItemContentsCalled = false
    public var createContentCalled = false
    public var updateContentCalled = false
    public var deleteContentCalled = false

    public var lastFetchItemId: String?
    public var lastCreateItemId: String?
    public var lastCreateRequest: ContentRequest?
    public var lastUpdateContentId: String?
    public var lastUpdateRequest: ContentRequest?
    public var lastDeleteContentId: String?

    // MARK: - Initialization

    public init() {}

    // MARK: - ContentServiceProtocol

    public func fetchItemContents(itemId: String) async throws -> [Content] {
        fetchItemContentsCalled = true
        lastFetchItemId = itemId
        switch fetchItemContentsResult {
        case let .success(contents):
            return contents
        case let .failure(error):
            throw error
        }
    }

    public func createContent(itemId: String, _ request: ContentRequest) async throws -> Content {
        createContentCalled = true
        lastCreateItemId = itemId
        lastCreateRequest = request

        if let result = createContentResult {
            switch result {
            case let .success(content):
                return content
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateContent(id: String, _ request: ContentRequest) async throws -> Content {
        updateContentCalled = true
        lastUpdateContentId = id
        lastUpdateRequest = request

        if let result = updateContentResult {
            switch result {
            case let .success(content):
                return content
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteContent(id: String) async throws {
        deleteContentCalled = true
        lastDeleteContentId = id

        switch deleteContentResult {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }
}
