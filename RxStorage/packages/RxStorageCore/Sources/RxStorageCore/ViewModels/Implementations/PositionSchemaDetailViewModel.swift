//
//  PositionSchemaDetailViewModel.swift
//  RxStorage
//
//  Position schema detail view model for displaying schema details
//

import Foundation
import Observation

/// Position schema detail view model
@Observable
@MainActor
public final class PositionSchemaDetailViewModel {
    // MARK: - Properties

    public private(set) var positionSchema: PositionSchema?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let schemaService: PositionSchemaServiceProtocol

    // MARK: - Initialization

    public init(schemaService: PositionSchemaServiceProtocol? = nil) {
        self.schemaService = schemaService ?? PositionSchemaService()
    }

    // MARK: - Public Methods

    public func fetchPositionSchema(id: Int) async {
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

    public func refresh() async {
        guard let schemaId = positionSchema?.id else { return }
        await fetchPositionSchema(id: schemaId)
    }

    public func clearError() {
        error = nil
    }
}
