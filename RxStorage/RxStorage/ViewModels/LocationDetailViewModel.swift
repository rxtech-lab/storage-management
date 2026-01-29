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
final class LocationDetailViewModel {
    // MARK: - Properties

    private(set) var location: Location?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol

    // MARK: - Initialization

    init(locationService: LocationServiceProtocol? = nil) {
        self.locationService = locationService ?? LocationService()
    }

    // MARK: - Public Methods

    func fetchLocation(id: Int) async {
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

    func refresh() async {
        guard let locationId = location?.id else { return }
        await fetchLocation(id: locationId)
    }

    func clearError() {
        error = nil
    }
}
