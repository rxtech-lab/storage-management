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
    private let eventViewModel: EventViewModel?
    @ObservationIgnored private nonisolated(unsafe) var eventTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        locationService: LocationServiceProtocol = LocationService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.locationService = locationService
        self.eventViewModel = eventViewModel
        setupSearchPipeline()
        setupEventSubscription()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Event Subscription

    private func setupEventSubscription() {
        guard let eventViewModel else { return }

        eventTask = Task { [weak self] in
            for await event in eventViewModel.stream {
                guard let self else { break }
                await self.handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: AppEvent) async {
        switch event {
        case .locationCreated, .locationUpdated, .locationDeleted:
            await refreshLocations()
        default:
            break
        }
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

    @discardableResult
    public func deleteLocation(_ location: Location) async throws -> Int {
        let locationId = location.id
        try await locationService.deleteLocation(id: locationId)

        // Remove from local list
        locations.removeAll { $0.id == locationId }

        // Emit event
        eventViewModel?.emit(.locationDeleted(id: locationId))

        return locationId
    }
}
