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

    public var lastFetchItemId: Int?
    public var lastCreateItemId: Int?
    public var lastCreateRequest: ContentRequest?
    public var lastUpdateContentId: Int?
    public var lastUpdateRequest: ContentRequest?
    public var lastDeleteContentId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - ContentServiceProtocol

    public func fetchItemContents(itemId: Int) async throws -> [Content] {
        fetchItemContentsCalled = true
        lastFetchItemId = itemId
        switch fetchItemContentsResult {
        case .success(let contents):
            return contents
        case .failure(let error):
            throw error
        }
    }

    public func createContent(itemId: Int, _ request: ContentRequest) async throws -> Content {
        createContentCalled = true
        lastCreateItemId = itemId
        lastCreateRequest = request

        if let result = createContentResult {
            switch result {
            case .success(let content):
                return content
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateContent(id: Int, _ request: ContentRequest) async throws -> Content {
        updateContentCalled = true
        lastUpdateContentId = id
        lastUpdateRequest = request

        if let result = updateContentResult {
            switch result {
            case .success(let content):
                return content
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteContent(id: Int) async throws {
        deleteContentCalled = true
        lastDeleteContentId = id

        switch deleteContentResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
