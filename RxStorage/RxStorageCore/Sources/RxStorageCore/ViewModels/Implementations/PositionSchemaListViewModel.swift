//
//  PositionSchemaListViewModel.swift
//  RxStorageCore
//
//  Position schema list view model implementation
//

import Foundation
import Observation

/// Position schema list view model implementation
@Observable
@MainActor
public final class PositionSchemaListViewModel: PositionSchemaListViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var schemas: [PositionSchema] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?
    public var searchText = ""

    // MARK: - Dependencies

    private let schemaService: PositionSchemaServiceProtocol

    // MARK: - Computed Properties

    public var filteredSchemas: [PositionSchema] {
        guard !searchText.isEmpty else { return schemas }
        return schemas.filter { schema in
            schema.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Initialization

    public init(schemaService: PositionSchemaServiceProtocol = PositionSchemaService()) {
        self.schemaService = schemaService
    }

    // MARK: - Public Methods

    public func fetchSchemas() async {
        isLoading = true
        error = nil

        do {
            schemas = try await schemaService.fetchPositionSchemas()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func refreshSchemas() async {
        await fetchSchemas()
    }

    public func deleteSchema(_ schema: PositionSchema) async throws {
        try await schemaService.deletePositionSchema(id: schema.id)

        // Remove from local list
        schemas.removeAll { $0.id == schema.id }
    }
}
