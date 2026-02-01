//
//  DashboardService.swift
//  RxStorageCore
//
//  Dashboard service protocol and implementation using generated client
//

import Foundation

// MARK: - Protocol

/// Protocol for dashboard service operations
public protocol DashboardServiceProtocol: Sendable {
    func fetchStats() async throws -> DashboardStats
}

// MARK: - Implementation

/// Dashboard service implementation using generated OpenAPI client
public struct DashboardService: DashboardServiceProtocol {
    public init() {}

    public func fetchStats() async throws -> DashboardStats {
        let client = StorageAPIClient.shared.client

        let response = try await client.getDashboardStats(.init())

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
