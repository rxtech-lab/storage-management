//
//  MockLocationService.swift
//  RxStorageCoreTests
//
//  Mock location service for testing
//

import Foundation
@testable import RxStorageCore

/// Mock location service for testing
@MainActor
public final class MockLocationService: LocationServiceProtocol {
    // MARK: - Properties

    public var fetchLocationsResult: Result<[Location], Error> = .success([])
    public var fetchLocationsPaginatedResult: Result<PaginatedResponse<Location>, Error>?
    public var fetchLocationResult: Result<Location, Error>?
    public var fetchLocationDetailResult: Result<LocationDetail, Error>?
    public var createLocationResult: Result<Location, Error>?
    public var updateLocationResult: Result<Location, Error>?
    public var deleteLocationResult: Result<Void, Error>?

    // Call tracking
    public var fetchLocationsCalled = false
    public var fetchLocationsPaginatedCalled = false
    public var fetchLocationCalled = false
    public var fetchLocationDetailCalled = false
    public var createLocationCalled = false
    public var updateLocationCalled = false
    public var deleteLocationCalled = false

    public var lastFetchLocationId: String?
    public var lastCreateLocationRequest: NewLocationRequest?
    public var lastUpdateLocationId: String?
    public var lastUpdateLocationRequest: UpdateLocationRequest?
    public var lastDeleteLocationId: String?

    // MARK: - Initialization

    public init() {}

    // MARK: - LocationServiceProtocol

    public func fetchLocations(filters _: LocationFilters?) async throws -> [Location] {
        fetchLocationsCalled = true
        switch fetchLocationsResult {
        case let .success(locations):
            return locations
        case let .failure(error):
            throw error
        }
    }

    public func fetchLocationsPaginated(filters: LocationFilters?) async throws -> PaginatedResponse<Location> {
        fetchLocationsPaginatedCalled = true
        if let result = fetchLocationsPaginatedResult {
            switch result {
            case let .success(response):
                return response
            case let .failure(error):
                throw error
            }
        }
        // Default: wrap fetchLocationsResult in paginated response
        let locations = try await fetchLocations(filters: filters)
        return PaginatedResponse(
            data: locations,
            pagination: PaginationState(hasNextPage: false, hasPrevPage: false, nextCursor: nil, prevCursor: nil)
        )
    }

    public func fetchLocation(id: String) async throws -> Location {
        fetchLocationCalled = true
        lastFetchLocationId = id

        if let result = fetchLocationResult {
            switch result {
            case let .success(location):
                return location
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func fetchLocationDetail(id: String) async throws -> LocationDetail {
        fetchLocationDetailCalled = true
        lastFetchLocationId = id

        if let result = fetchLocationDetailResult {
            switch result {
            case let .success(detail):
                return detail
            case let .failure(error):
                throw error
            }
        }

        // Fall back to fetchLocationResult, wrapping in LocationDetail with empty items
        if let result = fetchLocationResult {
            switch result {
            case let .success(location):
                return LocationDetail(id: location.id, userId: location.userId, title: location.title, latitude: location.latitude, longitude: location.longitude, createdAt: location.createdAt, updatedAt: location.updatedAt, items: [], totalItems: 0)
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func createLocation(_ request: NewLocationRequest) async throws -> Location {
        createLocationCalled = true
        lastCreateLocationRequest = request

        if let result = createLocationResult {
            switch result {
            case let .success(location):
                return location
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateLocation(id: String, _ request: UpdateLocationRequest) async throws -> Location {
        updateLocationCalled = true
        lastUpdateLocationId = id
        lastUpdateLocationRequest = request

        if let result = updateLocationResult {
            switch result {
            case let .success(location):
                return location
            case let .failure(error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteLocation(id: String) async throws {
        deleteLocationCalled = true
        lastDeleteLocationId = id

        if let result = deleteLocationResult {
            switch result {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }
    }
}
