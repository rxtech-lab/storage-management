//
//  MapPickerViewModel.swift
//  RxStorageCore
//
//  ViewModel for map-based location picker with search and user location
//

@preconcurrency import Combine
import CoreLocation
import Foundation
import MapKit
import Observation

/// Search result item for map picker
public struct MapSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let coordinate: CLLocationCoordinate2D

    public init(id: UUID = UUID(), title: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    public init(from mapItem: MKMapItem) {
        id = UUID()
        title = mapItem.name ?? "Unknown"
        subtitle = mapItem.placemark.formattedAddress ?? ""
        coordinate = mapItem.placemark.coordinate
    }
}

/// Authorization status for location services
public enum LocationAuthorizationStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
}

/// View model for map-based location picker
@Observable
@MainActor
public final class MapPickerViewModel: NSObject {
    // MARK: - Published Properties

    /// Currently selected coordinate (for pin display)
    public var selectedCoordinate: CLLocationCoordinate2D?

    /// Map region for camera positioning
    public var mapRegion: MKCoordinateRegion

    /// Search text (triggers debounced search)
    public var searchText = ""

    /// Search results from MKLocalSearch
    public private(set) var searchResults: [MapSearchResult] = []

    /// Whether search is in progress
    public private(set) var isSearching = false

    /// User's current location (if authorized)
    public private(set) var userLocation: CLLocationCoordinate2D?

    /// Location authorization status
    public private(set) var authorizationStatus: LocationAuthorizationStatus = .notDetermined

    /// Whether user location is being fetched
    public private(set) var isLocatingUser = false

    /// Error message for display
    public private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>?

    // Default region (San Francisco)
    private let defaultCoordinate = CLLocationCoordinate2D(
        latitude: 37.7749,
        longitude: -122.4194
    )

    // MARK: - Initialization

    public override init() {
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        super.init()
        setupLocationManager()
        setupSearchPipeline()
        updateAuthorizationStatus()
    }

    public init(initialCoordinate: CLLocationCoordinate2D?) {
        if let coordinate = initialCoordinate {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        super.init()
        setupLocationManager()
        setupSearchPipeline()
        updateAuthorizationStatus()

        if let coordinate = initialCoordinate {
            selectedCoordinate = coordinate
        }
    }

    // MARK: - Setup Methods

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func setupSearchPipeline() {
        searchSubject
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                Task { @MainActor in
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func updateAuthorizationStatus() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .restricted:
            authorizationStatus = .restricted
        case .denied:
            authorizationStatus = .denied
        case .authorizedWhenInUse:
            authorizationStatus = .authorizedWhenInUse
        case .authorizedAlways:
            authorizationStatus = .authorizedAlways
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    // MARK: - Public Methods

    /// Request location permission
    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Get user's current location
    public func locateUser() {
        guard authorizationStatus == .authorizedWhenInUse ||
            authorizationStatus == .authorizedAlways
        else {
            requestLocationPermission()
            return
        }

        isLocatingUser = true
        locationManager.requestLocation()
    }

    /// Select current user location as the coordinate
    public func selectUserLocation() {
        guard let userLocation else {
            locateUser()
            return
        }
        selectCoordinate(userLocation)
    }

    /// Select a coordinate (from tap or search result)
    public func selectCoordinate(_ coordinate: CLLocationCoordinate2D, centerMap: Bool = true) {
        selectedCoordinate = coordinate
        if centerMap {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    /// Select a search result
    public func selectSearchResult(_ result: MapSearchResult) {
        selectCoordinate(result.coordinate)
        clearSearch()
    }

    /// Trigger search (debounced)
    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    /// Clear search text and results
    public func clearSearch() {
        searchText = ""
        searchResults = []
    }

    /// Check if user location is available
    public var canUseUserLocation: Bool {
        authorizationStatus == .authorizedWhenInUse ||
            authorizationStatus == .authorizedAlways
    }

    /// Check if should show permission prompt
    public var shouldShowLocationPermissionPrompt: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Private Methods

    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        guard !trimmedQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // Cancel previous search
        currentSearchTask?.cancel()

        isSearching = true
        errorMessage = nil

        currentSearchTask = Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = trimmedQuery

                // Search near selected coordinate or user location
                if let center = selectedCoordinate ?? userLocation {
                    request.region = MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    )
                }

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                guard !Task.isCancelled else { return }

                searchResults = response.mapItems.map { MapSearchResult(from: $0) }
            } catch {
                guard !Task.isCancelled else { return }
                if (error as NSError).code != MKError.placemarkNotFound.rawValue {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                }
                searchResults = []
            }

            isSearching = false
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MapPickerViewModel: CLLocationManagerDelegate {
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            userLocation = location.coordinate
            isLocatingUser = false

            // If no coordinate selected yet, use user location
            if selectedCoordinate == nil {
                selectCoordinate(location.coordinate)
            }
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            isLocatingUser = false
            errorMessage = "Failed to get location: \(error.localizedDescription)"
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationStatus()

            // Auto-locate if just authorized
            if authorizationStatus == .authorizedWhenInUse ||
                authorizationStatus == .authorizedAlways
            {
                locateUser()
            }
        }
    }
}

// MARK: - MKPlacemark Extension

extension MKPlacemark {
    var formattedAddress: String? {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode,
            country,
        ].compactMap { $0 }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}
