//
//  IsoJobDetailViewModel.swift
//  RxStorageCore
//
//  ISO job detail view model with live refresh support
//

import Foundation
import Observation

/// ISO job detail view model
@Observable
@MainActor
public final class IsoJobDetailViewModel {
    // MARK: - Properties

    public private(set) var job: IsoJobDetail?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let isoJobService: IsoJobServiceProtocol

    // MARK: - Initialization

    public init(isoJobService: IsoJobServiceProtocol = IsoJobService()) {
        self.isoJobService = isoJobService
    }

    // MARK: - Computed Properties

    /// Whether the job is still running, so the view should keep refreshing
    public var isRunning: Bool {
        job?.status == .running
    }

    /// Disc drives burning the job's discs
    public var driveTasks: [IsoJobTask] {
        job?.tasks.filter { $0.section == .drive } ?? []
    }

    /// ISO files being written or burned
    public var isoTasks: [IsoJobTask] {
        job?.tasks.filter { $0.section == .iso } ?? []
    }

    /// Content files being uploaded to an item
    public var fileTasks: [IsoJobTask] {
        job?.tasks.filter { $0.section == .file } ?? []
    }

    // MARK: - Public Methods

    public func fetchJob(id: String) async {
        isLoading = true
        error = nil

        do {
            job = try await isoJobService.fetchJob(id: id)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Reloads the job without showing a loading state, for live updates
    public func refresh() async {
        guard let id = job?.id else { return }

        do {
            job = try await isoJobService.fetchJob(id: id)
        } catch {
            self.error = error
        }
    }

    public func deleteJob() async throws {
        guard let id = job?.id else { return }
        try await isoJobService.deleteJob(id: id)
    }

    public func clearError() {
        error = nil
    }
}
