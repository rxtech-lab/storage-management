//
//  LocationService.swift
//  RxStorageCore
//
//  Location service protocol and implementation using generated client
//

import Foundation

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

    public func fetchLocationsPaginated(filters: LocationFilters?) async throws -> PaginatedResponse<Location> {
        let client = StorageAPIClient.shared.client

        let direction = filters?.direction.flatMap { Operations.getLocations.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getLocations.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        let response = try await client.getLocations(.init(query: query))

        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            let pagination = PaginationState(from: body.pagination)
            return PaginatedResponse(data: body.data, pagination: pagination)
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

    public func fetchLocation(id: Int) async throws -> Location {
        let client = StorageAPIClient.shared.client

        let response = try await client.getLocation(.init(path: .init(id: String(id))))

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

    public func createLocation(_ request: NewLocationRequest) async throws -> Location {
        let client = StorageAPIClient.shared.client

        let response = try await client.createLocation(.init(body: .json(request)))

        switch response {
        case .created(let createdResponse):
            return try createdResponse.body.json
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

    public func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location {
        let client = StorageAPIClient.shared.client

        let response = try await client.updateLocation(.init(path: .init(id: String(id)), body: .json(request)))

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

    public func deleteLocation(id: Int) async throws {
        let client = StorageAPIClient.shared.client

        let response = try await client.deleteLocation(.init(path: .init(id: String(id))))

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
