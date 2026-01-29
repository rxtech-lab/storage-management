//
//  LocationListViewModel.swift
//  RxStorageCore
//
//  Location list view model implementation
//

import Foundation
import Observation

/// Location list view model implementation
@Observable
@MainActor
public final class LocationListViewModel: LocationListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var locations: [Location] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol

    // MARK: - Computed Properties

    public var filteredLocations: [Location] {
        guard !searchText.isEmpty else { return locations }
        return locations.filter { location in
            location.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Initialization

    public init(locationService: LocationServiceProtocol = LocationService()) {
        self.locationService = locationService
    }

    // MARK: - Public Methods

    public func fetchLocations() async {
        isLoading = true
        error = nil

        do {
            locations = try await locationService.fetchLocations()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshLocations() async {
        await fetchLocations()
    }

    public func deleteLocation(_ location: Location) async throws {
        try await locationService.deleteLocation(id: location.id)

        // Remove from local list
        locations.removeAll { $0.id == location.id }
    }
}
