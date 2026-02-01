//
//  PositionSchemaListViewModel.swift
//  RxStorageCore
//
//  Position schema list view model implementation with pagination support
//

@preconcurrency import Combine
import Foundation
import Observation

/// Position schema list view model implementation
@Observable
@MainActor
public final class PositionSchemaListViewModel: PositionSchemaListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var schemas: [PositionSchema] = []
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

    private let schemaService: PositionSchemaServiceProtocol

    // MARK: - Initialization

    public init(schemaService: PositionSchemaServiceProtocol = PositionSchemaService()) {
        self.schemaService = schemaService
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

        // If empty, fetch all schemas
        if trimmedQuery.isEmpty {
            await fetchSchemas()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = PositionSchemaFilters(search: trimmedQuery, limit: PaginationDefaults.pageSize)
            let response = try await schemaService.fetchPositionSchemasPaginated(filters: filters)
            schemas = response.data
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

    public func fetchSchemas() async {
        isLoading = true
        error = nil

        // Reset pagination state
        nextCursor = nil
        hasNextPage = true

        do {
            let filters = PositionSchemaFilters(limit: PaginationDefaults.pageSize)
            let response = try await schemaService.fetchPositionSchemasPaginated(filters: filters)
            schemas = response.data
            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func loadMoreSchemas() async {
        guard !isLoadingMore, !isLoading, !isSearching, hasNextPage, let cursor = nextCursor else {
            return
        }

        isLoadingMore = true

        do {
            var filters = PositionSchemaFilters()
            if !searchText.isEmpty {
                filters.search = searchText
            }
            filters.cursor = cursor
            filters.direction = .next
            filters.limit = PaginationDefaults.pageSize

            let response = try await schemaService.fetchPositionSchemasPaginated(filters: filters)

            // Append new schemas (avoid duplicates)
            let existingIds = Set(schemas.map { $0.id })
            let newSchemas = response.data.filter { !existingIds.contains($0.id) }
            schemas.append(contentsOf: newSchemas)

            nextCursor = response.pagination.nextCursor
            hasNextPage = response.pagination.hasNextPage
            isLoadingMore = false
        } catch {
            self.error = error
            isLoadingMore = false
        }
    }

    public func refreshSchemas() async {
        if searchText.isEmpty {
            await fetchSchemas()
        } else {
            await performSearch(query: searchText)
        }
    }

    public func deleteSchema(_ schema: PositionSchema) async throws {
        try await schemaService.deletePositionSchema(id: schema.id)

        // Remove from local list
        schemas.removeAll { $0.id == schema.id }
    }
}
