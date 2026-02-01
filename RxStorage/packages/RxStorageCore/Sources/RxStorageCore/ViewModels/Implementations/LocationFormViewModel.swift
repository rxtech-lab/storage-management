//
//  LocationFormViewModel.swift
//  RxStorageCore
//
//  Location form view model implementation
//

import Foundation
import CoreLocation
import Observation

/// Location form view model implementation
@Observable
@MainActor
public final class LocationFormViewModel: LocationFormViewModelProtocol {
    // MARK: - Published Properties

    public let location: Location?

    // Form fields
    public var title = ""
    public var latitude = ""
    public var longitude = ""

    // State
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol
    private let eventViewModel: EventViewModel?

    // MARK: - Initialization

    public init(
        location: Location? = nil,
        locationService: LocationServiceProtocol = LocationService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.location = location
        self.locationService = locationService
        self.eventViewModel = eventViewModel

        // Populate form if editing
        if let location = location {
            populateForm(from: location)
        }
    }

    // MARK: - Public Methods

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate title
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["title"] = "Title is required"
        }

        // Validate latitude
        if latitude.isEmpty {
            validationErrors["latitude"] = "Latitude is required"
        } else if Double(latitude) == nil {
            validationErrors["latitude"] = "Invalid latitude format"
        } else if let lat = Double(latitude), lat < -90 || lat > 90 {
            validationErrors["latitude"] = "Latitude must be between -90 and 90"
        }

        // Validate longitude
        if longitude.isEmpty {
            validationErrors["longitude"] = "Longitude is required"
        } else if Double(longitude) == nil {
            validationErrors["longitude"] = "Invalid longitude format"
        } else if let lon = Double(longitude), lon < -180 || lon > 180 {
            validationErrors["longitude"] = "Longitude must be between -180 and 180"
        }

        return validationErrors.isEmpty
    }

    @discardableResult
    public func submit() async throws -> Location {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let latValue = Double(latitude)!
            let lonValue = Double(longitude)!

            let request = NewLocationRequest(
                title: title,
                latitude: latValue,
                longitude: lonValue
            )

            let result: Location
            if let existingLocation = location {
                // Update
                result = try await locationService.updateLocation(id: existingLocation.id, request)
                eventViewModel?.emit(.locationUpdated(id: result.id))
            } else {
                // Create
                result = try await locationService.createLocation(request)
                eventViewModel?.emit(.locationCreated(id: result.id))
            }

            isSubmitting = false
            return result
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    public func updateCoordinates(_ coordinate: CLLocationCoordinate2D) {
        latitude = String(format: "%.6f", coordinate.latitude)
        longitude = String(format: "%.6f", coordinate.longitude)
    }

    // MARK: - Private Methods

    private func populateForm(from location: Location) {
        title = location.title
        latitude = location.latitude.map { String($0) } ?? ""
        longitude = location.longitude.map { String($0) } ?? ""
    }
}
