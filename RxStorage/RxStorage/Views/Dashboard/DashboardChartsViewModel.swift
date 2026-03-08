//
//  DashboardChartsViewModel.swift
//  RxStorage
//
//  View model for the dashboard charts detail pane (iPad/macOS)
//

import Observation
import RxStorageCore

/// View model for Dashboard Charts
@Observable
@MainActor
final class DashboardChartsViewModel {
    // MARK: - Properties

    private(set) var charts: DashboardCharts?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Services

    private let dashboardService = DashboardService()

    // MARK: - Methods

    /// Load chart data
    func loadCharts() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            charts = try await dashboardService.fetchCharts()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Refresh chart data
    func refresh() async {
        await loadCharts()
    }

    /// Clear error state
    func clearError() {
        error = nil
    }
}
