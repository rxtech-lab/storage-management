//
//  PositionSchemaListViewModel.swift
//  RxStorageCore
//
//  Position schema list view model implementation
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

        // If empty, fetch all schemas
        if trimmedQuery.isEmpty {
            await fetchSchemas()
            return
        }

        isSearching = true
        error = nil

        do {
            let filters = PositionSchemaFilters(search: trimmedQuery, limit: 10)
            schemas = try await schemaService.fetchPositionSchemas(filters: filters)
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

        do {
            schemas = try await schemaService.fetchPositionSchemas(filters: nil)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
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
