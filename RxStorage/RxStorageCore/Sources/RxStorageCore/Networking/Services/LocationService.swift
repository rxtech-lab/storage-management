//
//  LocationService.swift
//  RxStorageCore
//
//  API service for location operations
//

import Foundation

/// Protocol for location service operations
public protocol LocationServiceProtocol {
    func fetchLocations() async throws -> [Location]
    func fetchLocation(id: Int) async throws -> Location
    func createLocation(_ request: NewLocationRequest) async throws -> Location
    func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location
    func deleteLocation(id: Int) async throws
}

/// Location service implementation
public class LocationService: LocationServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchLocations() async throws -> [Location] {
        return try await apiClient.get(
            .listLocations,
            responseType: [Location].self
        )
    }

    public func fetchLocation(id: Int) async throws -> Location {
        return try await apiClient.get(
            .getLocation(id: id),
            responseType: Location.self
        )
    }

    public func createLocation(_ request: NewLocationRequest) async throws -> Location {
        return try await apiClient.post(
            .createLocation,
            body: request,
            responseType: Location.self
        )
    }

    public func updateLocation(id: Int, _ request: UpdateLocationRequest) async throws -> Location {
        return try await apiClient.put(
            .updateLocation(id: id),
            body: request,
            responseType: Location.self
        )
    }

    public func deleteLocation(id: Int) async throws {
        try await apiClient.delete(.deleteLocation(id: id))
    }
}
