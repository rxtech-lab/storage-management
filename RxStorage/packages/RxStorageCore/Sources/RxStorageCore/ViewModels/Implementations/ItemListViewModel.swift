//
//  ItemListViewModel.swift
//  RxStorageCore
//
//  Item list view model implementation
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Item list view model implementation
@Observable
@MainActor
public final class ItemListViewModel: ItemListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var error: Error?
    public var filters = ItemFilters()
    public var searchText = ""

    // MARK: - Combine

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol
    private let logger = Logger(label: "com.rxlab.rxstorage.ItemListViewModel")

    // MARK: - Initialization

    public init(itemService: ItemServiceProtocol = ItemService()) {
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

        // Update filters with search query
        if trimmedQuery.isEmpty {
            filters.search = nil
        } else {
            filters.search = trimmedQuery
        }

        isSearching = true
        error = nil

        do {
            items = try await itemService.fetchItems(filters: filters.isEmpty ? nil : filters)
            isSearching = false
        } catch is CancellationError {
            isSearching = false
        } catch let apiError as APIError where apiError.isCancellation {
            isSearching = false
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            isSearching = false
        } catch {
            logger.error("Failed to search items: \(error.localizedDescription)", metadata: [
                "error": "\(error)"
            ])
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

    public func fetchItems() async {
        isLoading = true
        error = nil

        do {
            items = try await itemService.fetchItems(filters: filters.isEmpty ? nil : filters)
            isLoading = false
        } catch is CancellationError {
            // Task was cancelled (e.g., view dismissed) - ignore silently
            isLoading = false
        } catch let apiError as APIError where apiError.isCancellation {
            // Wrapped network cancellation - ignore silently
            isLoading = false
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Network request was cancelled - ignore silently
            isLoading = false
        } catch {
            logger.error("Failed to fetch items: \(error.localizedDescription)", metadata: [
                "error": "\(error)"
            ])
            self.error = error
            isLoading = false
        }
    }

    public func refreshItems() async {
        if searchText.isEmpty {
            await fetchItems()
        } else {
            await performSearch(query: searchText)
        }
    }

    public func deleteItem(_ item: StorageItem) async throws {
        try await itemService.deleteItem(id: item.id)

        // Remove from local list
        items.removeAll { $0.id == item.id }
    }

    public func clearFilters() {
        filters = ItemFilters()
        searchText = ""
    }

    public func applyFilters(_ filters: ItemFilters) {
        self.filters = filters
        if let search = filters.search {
            searchText = search
        }
    }

    public func clearError() {
        error = nil
    }
}

// MARK: - ItemFilters Extension

extension ItemFilters {
    /// Check if filters are empty
    var isEmpty: Bool {
        categoryId == nil &&
        locationId == nil &&
        authorId == nil &&
        parentId == nil &&
        visibility == nil &&
        search == nil
    }
}
