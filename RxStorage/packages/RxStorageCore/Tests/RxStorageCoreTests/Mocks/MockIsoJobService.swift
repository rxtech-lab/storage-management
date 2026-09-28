//
//  MockIsoJobService.swift
//  RxStorageCoreTests
//
//  Mock ISO job service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock ISO job service for testing
@MainActor
public final class MockIsoJobService: IsoJobServiceProtocol {
    // MARK: - Properties

    public var fetchJobsPaginatedResults: [Result<PaginatedResponse<IsoJob>, Error>] = []
    public var fetchJobResults: [Result<IsoJobDetail, Error>] = []
    public var deleteJobResult: Result<Void, Error> = .success(())

    // Call tracking
    public var fetchJobsFilters: [IsoJobFilters?] = []
    public var fetchJobIds: [String] = []
    public var deletedJobIds: [String] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - IsoJobServiceProtocol

    public func fetchJobsPaginated(filters: IsoJobFilters?) async throws -> PaginatedResponse<IsoJob> {
        fetchJobsFilters.append(filters)
        guard !fetchJobsPaginatedResults.isEmpty else {
            return PaginatedResponse(data: [], pagination: PaginationState(hasNextPage: false, hasPrevPage: false, nextCursor: nil, prevCursor: nil))
        }
        return try fetchJobsPaginatedResults.removeFirst().get()
    }

    public func fetchJob(id: String) async throws -> IsoJobDetail {
        fetchJobIds.append(id)
        guard !fetchJobResults.isEmpty else {
            throw APIError.notFound
        }
        return try fetchJobResults.removeFirst().get()
    }

    public func deleteJob(id: String) async throws {
        deletedJobIds.append(id)
        try deleteJobResult.get()
    }
}
