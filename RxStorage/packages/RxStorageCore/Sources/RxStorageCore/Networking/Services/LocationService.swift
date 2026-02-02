//
//  LocationService.swift
//  RxStorageCore
//
//  Location service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

fileprivate let logger = Logger(label: "LocationService")

// MARK: - Protocol

/// Protocol for location service operations
public protocol LocationServiceProtocol: Sendable {
    func fetchLocations(filters: LocationFilters?) async throws -> [Location]
    func fetchLocationsPaginated(filters: LocationFilters?) async throws -> PaginatedResponse<Location>
    func fetchLocation(id: Int) async throws -> Location
    func createLocation(_ request: NewLocationRequest) async throws -> Location
    func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location
    func deleteLocation(id: Int) async throws
}

// MARK: - Implementation

/// Location service implementation using generated OpenAPI client
public struct LocationService: LocationServiceProtocol {
    public init() {}

    public func fetchLocations(filters: LocationFilters?) async throws -> [Location] {
        let response = try await fetchLocationsPaginated(filters: filters)
        return response.data
    }

    @APICall(.ok, transform: "transformPaginatedLocations")
    public func fetchLocationsPaginated(filters: LocationFilters?) async throws -> PaginatedResponse<Location> {
        let direction = filters?.direction.flatMap { Operations.getLocations.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getLocations.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        try await StorageAPIClient.shared.client.getLocations(.init(query: query))
    }

    /// Transforms paginated locations response to PaginatedResponse
    private func transformPaginatedLocations(_ body: Components.Schemas.PaginatedLocationsResponse) -> PaginatedResponse<Location> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok)
    public func fetchLocation(id: Int) async throws -> Location {
        try await StorageAPIClient.shared.client.getLocation(.init(path: .init(id: String(id))))
    }

    @APICall(.created)
    public func createLocation(_ request: NewLocationRequest) async throws -> Location {
        try await StorageAPIClient.shared.client.createLocation(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location {
        try await StorageAPIClient.shared.client.updateLocation(.init(path: .init(id: String(id)), body: .json(request)))
    }

    public func deleteLocation(id: Int) async throws {
        let response = try await StorageAPIClient.shared.client.deleteLocation(.init(path: .init(id: String(id))))

        switch response {
        case .ok:
            return
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
