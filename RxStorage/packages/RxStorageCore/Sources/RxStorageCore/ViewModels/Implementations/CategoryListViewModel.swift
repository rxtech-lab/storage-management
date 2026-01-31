//
//  CategoryListViewModel.swift
//  RxStorageCore
//
//  Category list view model implementation
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

        // If empty, fetch all categories
        if trimmedQuery.isEmpty {
            await fetchCategories()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = CategoryFilters(search: trimmedQuery, limit: 10)
            categories = try await categoryService.fetchCategories(filters: filters)
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

        do {
            categories = try await categoryService.fetchCategories(filters: nil)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
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
