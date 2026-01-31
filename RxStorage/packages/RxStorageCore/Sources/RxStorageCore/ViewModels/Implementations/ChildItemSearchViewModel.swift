//
//  ChildItemSearchViewModel.swift
//  RxStorageCore
//
//  ViewModel for searching items to add as children with Combine debounce
//

@preconcurrency import Combine
import Foundation
import Observation

/// View model for searching and selecting items to add as children
@Observable
@MainActor
public final class ChildItemSearchViewModel {
    // MARK: - Published Properties

    public private(set) var searchResults: [StorageItem] = []
    public private(set) var isSearching = false
    public private(set) var error: Error?

    /// Default items shown when search text is empty (limited to 10)
    public private(set) var defaultItems: [StorageItem] = []
    public private(set) var isLoadingDefaults = false

    /// Search text - triggers debounced API call
    public var searchText = ""

    // MARK: - Private Properties

    /// Items to exclude from results (current item + existing children)
    private var excludedItemIds: Set<Int>

    // MARK: - Combine

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol

    // MARK: - Initialization

    public init(
        excludedItemIds: Set<Int> = [],
        itemService: ItemServiceProtocol = ItemService()
    ) {
        self.excludedItemIds = excludedItemIds
        self.itemService = itemService
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

        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = ItemFilters(search: trimmedQuery)
            let results = try await itemService.fetchItems(filters: filters)
            // Filter out excluded items
            searchResults = results.filter { !excludedItemIds.contains($0.id) }
            isSearching = false
        } catch {
            self.error = error
            isSearching = false
        }
    }

    // MARK: - Public Methods

    /// Load default items to display when search text is empty (limited to 10)
    public func loadDefaultItems() async {
        isLoadingDefaults = true
        error = nil

        do {
            let results = try await itemService.fetchItems(filters: nil)
            // Filter excluded items and limit to 10
            defaultItems = Array(
                results.filter { !excludedItemIds.contains($0.id) }.prefix(10)
            )
            isLoadingDefaults = false
        } catch {
            self.error = error
            isLoadingDefaults = false
        }
    }

    /// Trigger a search with the given query (debounced)
    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    /// Update the set of excluded item IDs
    public func updateExcludedIds(_ ids: Set<Int>) {
        excludedItemIds = ids
        // Re-filter current results and default items
        searchResults = searchResults.filter { !excludedItemIds.contains($0.id) }
        defaultItems = defaultItems.filter { !excludedItemIds.contains($0.id) }
    }

    /// Clear search results and text
    public func clearSearch() {
        searchText = ""
        searchResults = []
        error = nil
    }
}
