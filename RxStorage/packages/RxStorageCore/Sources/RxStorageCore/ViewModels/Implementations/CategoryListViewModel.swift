//
//  CategoryListViewModel.swift
//  RxStorageCore
//
//  Category list view model implementation with pagination support
//

@preconcurrency import Combine
import Foundation
import Observation

/// Category list view model implementation
@Observable
@MainActor
public final class CategoryListViewModel: CategoryListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var categories: [Category] = []
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

    private let categoryService: CategoryServiceProtocol

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

        // Reset pagination state for new search
        nextCursor = nil
        hasNextPage = true

        // If empty, fetch all categories
        if trimmedQuery.isEmpty {
            await fetchCategories()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = CategoryFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await categoryService.fetchCategoriesPaginated(filters: filters)
            categories = response.data
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

    public func fetchCategories() async {
        isLoading = true
        error = nil

        // Reset pagination state
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = CategoryFilters(limit: PaginationDefaults.pageSize)
            let response = try await categoryService.fetchCategoriesPaginated(filters: filters)
            categories = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func loadMoreCategories() async {
        guard !isLoadingMore, !isLoading, !isSearching, hasNextPage, let cursor = nextCursor else {
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

            // Append new categories (avoid duplicates)
            let existingIds = Set(categories.map { $0.id })
            let newCategories = response.data.filter { !existingIds.contains($0.id) }
            categories.append(contentsOf: newCategories)

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoadingMore = false
        } catch {
            self.error = error
            isLoadingMore = false
        }
    }

    public func refreshCategories() async {
        if searchText.isEmpty {
            await fetchCategories()
        } else {
            await performSearch(query: searchText)
        }
    }

    public func deleteCategory(_ category: Category) async throws {
        try await categoryService.deleteCategory(id: category.id)

        // Remove from local list
        categories.removeAll { $0.id == category.id }
    }
}
