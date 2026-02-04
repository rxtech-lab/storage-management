//
//  ContentSchemaService.swift
//  RxStorageCore
//
//  Content schema service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "ContentSchemaService")

// MARK: - Protocol

/// Protocol for content schema service operations
public protocol ContentSchemaServiceProtocol: Sendable {
    func fetchContentSchemas() async throws -> [ContentSchema]
}

// MARK: - Implementation

/// Content schema service implementation using generated OpenAPI client
public struct ContentSchemaService: ContentSchemaServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func fetchContentSchemas() async throws -> [ContentSchema] {
        try await StorageAPIClient.shared.client.getContentSchemas(.init())
    }
}
