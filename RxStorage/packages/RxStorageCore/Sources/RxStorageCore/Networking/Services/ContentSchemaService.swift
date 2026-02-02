//
//  ContentSchemaService.swift
//  RxStorageCore
//
//  Content schema service protocol and implementation using generated client
//

import Foundation

// MARK: - Protocol

/// Protocol for content schema service operations
public protocol ContentSchemaServiceProtocol: Sendable {
    func fetchContentSchemas() async throws -> [ContentSchema]
}

// MARK: - Implementation

/// Content schema service implementation using generated OpenAPI client
public struct ContentSchemaService: ContentSchemaServiceProtocol {
    public init() {}

    public func fetchContentSchemas() async throws -> [ContentSchema] {
        let client = StorageAPIClient.shared.client

        let response = try await client.getContentSchemas(.init())

        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest(let badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case .undocumented(let statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
