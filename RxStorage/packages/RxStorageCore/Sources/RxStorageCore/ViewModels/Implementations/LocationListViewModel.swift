//
//  LocationListViewModel.swift
//  RxStorageCore
//
//  Location list view model implementation
//

@preconcurrency import Combine
import Foundation
import Observation

/// Location list view model implementation
@Observable
@MainActor
public final class LocationListViewModel: LocationListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var locations: [Location] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Combine

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol

    // MARK: - Initialization

    public init(locationService: LocationServiceProtocol = LocationService()) {
        self.locationService = locationService
        setupSearchPipeline()
    }

    // MARK: - Private Methods

    private func setupSearchPipeline() {
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                Task { @MainActor in
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        // If empty, fetch all locations
        if trimmedQuery.isEmpty {
            await fetchLocations()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = LocationFilters(search: trimmedQuery, limit: 10)
            locations = try await locationService.fetchLocations(filters: filters)
            isSearching = false
        } catch {
            self.error = error
            isSearching = false
        }
    }

    // MARK: - Public Methods

    /// Trigger a search with the given query (debounced)
    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func fetchLocations() async {
        isLoading = true
        error = nil

        do {
            locations = try await locationService.fetchLocations(filters: nil)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshLocations() async {
        if searchText.isEmpty {
            await fetchLocations()
        } else {
            await performSearch(query: searchText)
        }
    }

    public func deleteLocation(_ location: Location) async throws {
        try await locationService.deleteLocation(id: location.id)

        // Remove from local list
        locations.removeAll { $0.id == location.id }
    }
}
