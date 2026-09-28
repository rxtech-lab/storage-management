//
//  IsoJobListViewModel.swift
//  RxStorageCore
//
//  ISO job list view model with pagination and live refresh support
//

import Foundation
import Observation

/// ISO job list view model
@Observable
@MainActor
public final class IsoJobListViewModel {
    // MARK: - Properties

    public private(set) var jobs: [IsoJob] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?

    /// Only show jobs of this kind; nil shows every job
    public private(set) var kindFilter: IsoJobKind?

    // MARK: - Pagination State

    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    public private(set) var totalCount: Int = 0
    private var nextCursor: String?

    // MARK: - Dependencies

    private let isoJobService: IsoJobServiceProtocol

    // MARK: - Initialization

    public init(isoJobService: IsoJobServiceProtocol = IsoJobService()) {
        self.isoJobService = isoJobService
    }

    // MARK: - Computed Properties

    /// Whether any loaded job is still running, so the list should keep refreshing
    public var hasRunningJobs: Bool {
        jobs.contains { $0.status == .running }
    }

    // MARK: - Public Methods

    public func fetchJobs() async {
        isLoading = true
        error = nil
        await reload()
        isLoading = false
    }

    /// Reloads the first page without showing a loading state, for live updates
    public func refreshJobs() async {
        await reload()
    }

    public func setKindFilter(_ kind: IsoJobKind?) async {
        guard kind != kindFilter else { return }
        kindFilter = kind
        jobs = []
        await fetchJobs()
    }

    public func loadMoreJobs() async {
        guard !isLoadingMore, !isLoading, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            let filters = IsoJobFilters(
                kind: kindFilter,
                cursor: cursor,
                direction: .next,
                limit: PaginationDefaults.pageSize
            )
            let response = try await isoJobService.fetchJobsPaginated(filters: filters)

            let existingIds = Set(jobs.map { $0.id })
            jobs.append(contentsOf: response.data.filter { !existingIds.contains($0.id) })
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            totalCount = response.pagination.totalCount
        } catch {
            self.error = error
        }

        isLoadingMore = false
    }

    @discardableResult
    public func deleteJob(_ job: IsoJob) async throws -> String {
        try await isoJobService.deleteJob(id: job.id)
        jobs.removeAll { $0.id == job.id }
        totalCount = max(0, totalCount - 1)
        return job.id
    }

    public func clearError() {
        error = nil
    }

    // MARK: - Private Methods

    private func reload() async {
        do {
            let filters = IsoJobFilters(kind: kindFilter, limit: PaginationDefaults.pageSize)
            let response = try await isoJobService.fetchJobsPaginated(filters: filters)
            jobs = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            totalCount = response.pagination.totalCount
        } catch {
            self.error = error
        }
    }
}
