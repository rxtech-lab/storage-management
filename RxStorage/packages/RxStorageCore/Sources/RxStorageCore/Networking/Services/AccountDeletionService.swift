//
//  AccountDeletionService.swift
//  RxStorageCore
//
//  Account deletion service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "AccountDeletionService")

// MARK: - Protocol

/// Protocol for account deletion service operations
public protocol AccountDeletionServiceProtocol: Sendable {
    func getStatus() async throws -> AccountDeletionStatus
    func requestDeletion() async throws -> AccountDeletionRequestResponse
    func cancelDeletion() async throws
}

// MARK: - Implementation

/// Account deletion service implementation using generated OpenAPI client
public struct AccountDeletionService: AccountDeletionServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func getStatus() async throws -> AccountDeletionStatus {
        try await StorageAPIClient.shared.client.getAccountDeletionStatus(.init())
    }

    @APICall(.created)
    public func requestDeletion() async throws -> AccountDeletionRequestResponse {
        try await StorageAPIClient.shared.client.requestAccountDeletion(.init())
    }

    public func cancelDeletion() async throws {
        let response = try await StorageAPIClient.shared.client.cancelAccountDeletion(.init())

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
