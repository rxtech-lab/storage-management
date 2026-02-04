//
//  MockContentSchemaService.swift
//  RxStorageCoreTests
//
//  Mock content schema service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock content schema service for testing
@MainActor
public final class MockContentSchemaService: ContentSchemaServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    public var fetchContentSchemasResult: Result<[ContentSchema], Error> = .success([])

    /// Call tracking
    public var fetchContentSchemasCalled = false

    // MARK: - Initialization

    public init() {}

    // MARK: - ContentSchemaServiceProtocol

    public func fetchContentSchemas() async throws -> [ContentSchema] {
        fetchContentSchemasCalled = true
        switch fetchContentSchemasResult {
        case let .success(schemas):
            return schemas
        case let .failure(error):
            throw error
        }
    }
}
