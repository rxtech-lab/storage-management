//
//  CategoryPickerViewModel.swift
//  RxStorageCore
//
//  Category picker view model with search and pagination
//

@preconcurrency import Combine
import Foundation
import Logging
import Observation

/// Category picker view model for searchable selection
@Observable
@MainActor
public final class CategoryPickerViewModel {
    // MARK: - Published Properties

    public private(set) var categories: [Category] = []
    public private(set) var searchResults: [Category] = []
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

    private let categoryService: CategoryServiceProtocol
    private let logger = Logger(label: "com.rxlab.rxstorage.CategoryPickerViewModel")

    // MARK: - Initialization

    public init(categoryService: CategoryServiceProtocol = CategoryService()) {
        self.categoryService = categoryService
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
            let filters = CategoryFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await categoryService.fetchCategoriesPaginated(filters: filters)
            searchResults = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Category search failed: \(error.localizedDescription)")
        }

        isSearching = false
    }

    // MARK: - Public Methods

    public func search(_ query: String) {
        searchText = query
        searchSubject.send(query)
    }

    public func loadCategories() async {
        isLoading = true
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = CategoryFilters(limit: PaginationDefaults.pageSize)
            let response = try await categoryService.fetchCategoriesPaginated(filters: filters)
            categories = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load categories: \(error.localizedDescription)")
        }

        isLoading = false
    }

    public func loadMore() async {
        guard !isLoadingMore, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = CategoryFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await categoryService.fetchCategoriesPaginated(filters: filters)

            if searchText.isEmpty {
                let existingIds = Set(categories.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                categories.append(contentsOf: newItems)
            } else {
                let existingIds = Set(searchResults.map { $0.id })
                let newItems = response.data.filter { !existingIds.contains($0.id) }
                searchResults.append(contentsOf: newItems)
            }

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
        } catch {
            logger.debug("Failed to load more categories: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Get the current list of items to display
    public var displayItems: [Category] {
        searchText.isEmpty ? categories : searchResults
    }

    /// Check if should load more for a given item
    public func shouldLoadMore(for category: Category) -> Bool {
        let items = displayItems
        guard let index = items.firstIndex(where: { $0.id == category.id }) else {
            return false
        }
        let threshold = 3
        return index >= items.count - threshold && hasNextPage && !isLoadingMore && !isLoading
    }
}
