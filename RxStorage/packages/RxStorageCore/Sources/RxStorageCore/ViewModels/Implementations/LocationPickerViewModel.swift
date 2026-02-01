//
//  LocationPickerViewModel.swift
//  RxStorageCore
//
//  Location picker view model with search and pagination
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Location picker view model for searchable selection
@Observable
@MainActor
public final class LocationPickerViewModel {
    // MARK: - Published Properties

    public private(set) var locations: [Location] = []
    public private(set) var searchResults: [Location] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var isLoadingMore = false
    public private(set) var hasNextPage = true
    public var searchText = ""

    // MARK: - Private Properties

    private var nextCursor: String?
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol
    private let logger = Logger(label: "com.rxlab.rxstorage.LocationPickerViewModel")

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

        // Reset pagination
        nextCursor = nil
        hasNextPage = true

        if trimmedQuery.isEmpty {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        do {
            let filters = LocationFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await locationService.fetchLocationsPaginated(filters: filters)
            searchResults = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Location search failed: \(error.localizedDescription)")
        }

        isSearching = false
    }

    // MARK: - Public Methods

    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func loadLocations() async {
        isLoading = true
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = LocationFilters(limit: PaginationDefaults.pageSize)
            let response = try await locationService.fetchLocationsPaginated(filters: filters)
            locations = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load locations: \(error.localizedDescription)")
        }

        isLoading = false
    }

    public func loadMore() async {
        guard !isLoadingMore, hasNextPage, let cursor = nextCursor else {
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

            if searchText.isEmpty {
                let existingIds = Set(locations.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                locations.append(contentsOf: newItems)
            } else {
                let existingIds = Set(searchResults.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                searchResults.append(contentsOf: newItems)
            }

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load more locations: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Get the current list of items to display
    public var displayItems: [Location] {
        searchText.isEmpty ? locations : searchResults
    }

    /// Check if should load more for a given item
    public func shouldLoadMore(for location: Location) -> Bool {
        let items = displayItems
        guard let index = items.firstIndex(where: { $0.id == location.id }) else {
            return false
        }
        let threshold = 3
        return index >= items.count - threshold && hasNextPage && !isLoadingMore && !isLoading
    }
}
