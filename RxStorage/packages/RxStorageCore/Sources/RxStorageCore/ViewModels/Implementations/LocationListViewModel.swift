//
//  LocationListViewModel.swift
//  RxStorageCore
//
//  Location list view model implementation with pagination support
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

    // MARK: - Pagination State

    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    private var nextCursor: String?

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

        // Reset pagination state for new search
        nextCursor = nil
        hasNextPage = true

        // If empty, fetch all locations
        if trimmedQuery.isEmpty {
            await fetchLocations()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = LocationFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await locationService.fetchLocationsPaginated(filters: filters)
            locations = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
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

        // Reset pagination state
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = LocationFilters(limit: PaginationDefaults.pageSize)
            let response = try await locationService.fetchLocationsPaginated(filters: filters)
            locations = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func loadMoreLocations() async {
        guard !isLoadingMore, !isLoading, !isSearching, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = LocationFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await locationService.fetchLocationsPaginated(filters: filters)

            // Append new locations (avoid duplicates)
            let existingIds = Set(locations.map { $0.id })
            let newLocations = response.data.filter { !existingIds.contains($0.id) }
            locations.append(contentsOf: newLocations)

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoadingMore = false
        } catch {
            self.error = error
            isLoadingMore = false
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
