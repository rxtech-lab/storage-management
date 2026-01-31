//
//  LocationDetailViewModel.swift
//  RxStorage
//
//  Location detail view model for displaying location details
//

import Foundation
import Observation
import RxStorageCore

/// Location detail view model
@Observable
@MainActor
public final class LocationDetailViewModel {
    // MARK: - Properties

    public private(set) var location: Location?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol

    // MARK: - Initialization

    public init(locationService: LocationServiceProtocol? = nil) {
        self.locationService = locationService ?? LocationService()
    }

    // MARK: - Public Methods

    public func fetchLocation(id: Int) async {
        isLoading = true
        error = nil

        do {
            location = try await locationService.fetchLocation(id: id)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refresh() async {
        guard let locationId = location?.id else { return }
        await fetchLocation(id: locationId)
    }

    public func clearError() {
        error = nil
    }
}
