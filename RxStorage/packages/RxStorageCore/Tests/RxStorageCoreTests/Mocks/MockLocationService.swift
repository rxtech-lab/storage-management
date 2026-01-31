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
    public var fetchLocationResult: Result<Location, Error>?
    public var createLocationResult: Result<Location, Error>?
    public var updateLocationResult: Result<Location, Error>?
    public var deleteLocationResult: Result<Void, Error>?

    // Call tracking
    public var fetchLocationsCalled = false
    public var fetchLocationCalled = false
    public var createLocationCalled = false
    public var updateLocationCalled = false
    public var deleteLocationCalled = false

    public var lastFetchLocationId: Int?
    public var lastCreateLocationRequest: NewLocationRequest?
    public var lastUpdateLocationId: Int?
    public var lastUpdateLocationRequest: UpdateLocationRequest?
    public var lastDeleteLocationId: Int?

    // MARK: - Initialization

    public init() {}

    // MARK: - LocationServiceProtocol

    public func fetchLocations(filters: LocationFilters?) async throws -> [Location] {
        fetchLocationsCalled = true
        switch fetchLocationsResult {
        case .success(let locations):
            return locations
        case .failure(let error):
            throw error
        }
    }

    public func fetchLocation(id: Int) async throws -> Location {
        fetchLocationCalled = true
        lastFetchLocationId = id

        if let result = fetchLocationResult {
            switch result {
            case .success(let location):
                return location
            case .failure(let error):
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
            case .success(let location):
                return location
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location {
        updateLocationCalled = true
        lastUpdateLocationId = id
        lastUpdateLocationRequest = request

        if let result = updateLocationResult {
            switch result {
            case .success(let location):
                return location
            case .failure(let error):
                throw error
            }
        }

        throw APIError.serverError("Not configured")
    }

    public func deleteLocation(id: Int) async throws {
        deleteLocationCalled = true
        lastDeleteLocationId = id

        if let result = deleteLocationResult {
            switch result {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        }
    }
}
