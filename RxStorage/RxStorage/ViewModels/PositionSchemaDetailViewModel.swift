//
//  PositionSchemaDetailViewModel.swift
//  RxStorage
//
//  Position schema detail view model for displaying schema details
//

import Foundation
import Observation
import RxStorageCore

/// Position schema detail view model
@Observable
@MainActor
final class PositionSchemaDetailViewModel {
    // MARK: - Properties

    private(set) var positionSchema: PositionSchema?
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Dependencies

    private let schemaService: PositionSchemaServiceProtocol

    // MARK: - Initialization

    init(schemaService: PositionSchemaServiceProtocol? = nil) {
        self.schemaService = schemaService ?? PositionSchemaService()
    }

    // MARK: - Public Methods

    func fetchPositionSchema(id: Int) async {
        isLoading = true
        error = nil

        do {
            positionSchema = try await schemaService.fetchPositionSchema(id: id)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refresh() async {
        guard let schemaId = positionSchema?.id else { return }
        await fetchPositionSchema(id: schemaId)
    }

    func clearError() {
        error = nil
    }
}
