//
//  LiveActivityService.swift
//  RxStorageCore
//
//  Registers ActivityKit push tokens so the server can start and update ISO
//  job Live Activities
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "LiveActivityService")

// MARK: - Protocol

/// Protocol for Live Activity push token registration
public protocol LiveActivityServiceProtocol: Sendable {
    func registerToken(_ request: LiveActivityTokenRegisterRequest) async throws -> LiveActivityToken
    func unregisterToken(token: String) async throws
}

// MARK: - Implementation

/// Live Activity service implementation using generated OpenAPI client
public struct LiveActivityService: LiveActivityServiceProtocol {
    public init() {}

    @APICall(.created)
    public func registerToken(_ request: LiveActivityTokenRegisterRequest) async throws -> LiveActivityToken {
        try await StorageAPIClient.shared.client.registerLiveActivityToken(.init(body: .json(request)))
    }

    public func unregisterToken(token: String) async throws {
        let response = try await StorageAPIClient.shared.client.unregisterLiveActivityToken(
            .init(path: .init(token: token))
        )

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
