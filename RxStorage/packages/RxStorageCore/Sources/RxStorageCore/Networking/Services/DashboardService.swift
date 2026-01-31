//
//  DashboardService.swift
//  RxStorageCore
//
//  API service for dashboard operations
//

import Foundation

/// Protocol for dashboard service operations
@MainActor
public protocol DashboardServiceProtocol {
    func fetchDashboardStats() async throws -> DashboardStats
}

/// Dashboard service implementation
@MainActor
public class DashboardService: DashboardServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchDashboardStats() async throws -> DashboardStats {
        return try await apiClient.get(
            .getDashboardStats,
            responseType: DashboardStats.self
        )
    }
}
