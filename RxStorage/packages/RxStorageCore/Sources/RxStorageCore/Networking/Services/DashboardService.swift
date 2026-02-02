//
//  DashboardService.swift
//  RxStorageCore
//
//  Dashboard service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "DashboardService")

// MARK: - Protocol

/// Protocol for dashboard service operations
public protocol DashboardServiceProtocol: Sendable {
    func fetchStats() async throws -> DashboardStats
}

// MARK: - Implementation

/// Dashboard service implementation using generated OpenAPI client
public struct DashboardService: DashboardServiceProtocol {
    public init() {}

    @APICall(.ok)
    public func fetchStats() async throws -> DashboardStats {
        try await StorageAPIClient.shared.client.getDashboardStats(.init())
    }
}
