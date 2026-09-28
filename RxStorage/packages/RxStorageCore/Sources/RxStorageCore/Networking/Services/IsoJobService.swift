//
//  IsoJobService.swift
//  RxStorageCore
//
//  ISO job service for following iso-burner generation and burning progress
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "IsoJobService")

// MARK: - Protocol

/// Protocol for ISO job service operations
public protocol IsoJobServiceProtocol: Sendable {
    func fetchJobsPaginated(filters: IsoJobFilters?) async throws -> PaginatedResponse<IsoJob>
    func fetchJob(id: String) async throws -> IsoJobDetail
    func deleteJob(id: String) async throws
}

// MARK: - Implementation

/// ISO job service implementation using generated OpenAPI client
public struct IsoJobService: IsoJobServiceProtocol {
    public init() {}

    @APICall(.ok, transform: "transformPaginatedJobs")
    public func fetchJobsPaginated(filters: IsoJobFilters?) async throws -> PaginatedResponse<IsoJob> {
        let direction = filters?.direction.flatMap { Operations.getIsoJobs.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getIsoJobs.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            kind: filters?.kind.flatMap { Operations.getIsoJobs.Input.Query.kindPayload(rawValue: $0.rawValue) },
            status: filters?.status.flatMap { Operations.getIsoJobs.Input.Query.statusPayload(rawValue: $0.rawValue) }
        )

        try await StorageAPIClient.shared.client.getIsoJobs(.init(query: query))
    }

    private func transformPaginatedJobs(_ body: Components.Schemas.PaginatedIsoJobsResponse) -> PaginatedResponse<IsoJob> {
        PaginatedResponse(data: body.data, pagination: PaginationState(from: body.pagination))
    }

    @APICall(.ok)
    public func fetchJob(id: String) async throws -> IsoJobDetail {
        try await StorageAPIClient.shared.client.getIsoJob(.init(path: .init(id: id)))
    }

    public func deleteJob(id: String) async throws {
        let response = try await StorageAPIClient.shared.client.deleteIsoJob(.init(path: .init(id: id)))

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
