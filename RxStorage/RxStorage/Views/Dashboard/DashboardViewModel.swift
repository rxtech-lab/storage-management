//
//  DashboardViewModel.swift
//  RxStorage
//
//  View model for the dashboard with stats and recent items
//

import Observation
import RxStorageCore

/// View model for the Dashboard
@Observable
@MainActor
final class DashboardViewModel {
    // MARK: - Properties

    private(set) var stats: DashboardStats?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Services

    private let dashboardService = DashboardService()

    // MARK: - Computed Properties

    /// Recent items from the stats response
    var recentItems: [StorageItem] {
        stats?.recentItems ?? []
    }

    // MARK: - Methods

    /// Load all dashboard data
    func loadDashboard() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            stats = try await dashboardService.fetchStats()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Refresh dashboard data
    func refresh() async {
        await loadDashboard()
    }

    /// Clear error state
    func clearError() {
        error = nil
    }
}
