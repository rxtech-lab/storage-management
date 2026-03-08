//
//  LocationDetailViewModel.swift
//  RxStorage
//
//  Location detail view model for displaying location details
//

import Foundation
import Observation

/// Location detail view model
@Observable
@MainActor
public final class LocationDetailViewModel {
    // MARK: - Properties

    public private(set) var location: Location?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Items Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var totalItems: Int = 0

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol

    // MARK: - Initialization

    public init(locationService: LocationServiceProtocol? = nil) {
        self.locationService = locationService ?? LocationService()
    }

    // MARK: - Public Methods

    public func fetchLocation(id: String) async {
        isLoading = true
        error = nil

        do {
            let detail = try await locationService.fetchLocationDetail(id: id)
            location = Location(id: detail.id, userId: detail.userId, title: detail.title, latitude: detail.latitude, longitude: detail.longitude, createdAt: detail.createdAt, updatedAt: detail.updatedAt)
            items = detail.items
            totalItems = detail.totalItems
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
