//
//  PositionSchemaFormViewModel.swift
//  RxStorageCore
//
//  Position schema form view model implementation
//

import Foundation
import Observation
import OpenAPIRuntime

/// Position schema form view model implementation
@Observable
@MainActor
public final class PositionSchemaFormViewModel: PositionSchemaFormViewModelProtocol {
    // MARK: - Published Properties

    public let schema: PositionSchema?

    // Form fields
    public var name = ""
    public var schemaJSON = ""

    // State
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let schemaService: PositionSchemaServiceProtocol
    private let eventViewModel: EventViewModel?

    // MARK: - Initialization

    public init(
        schema: PositionSchema? = nil,
        schemaService: PositionSchemaServiceProtocol = PositionSchemaService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.schema = schema
        self.schemaService = schemaService
        self.eventViewModel = eventViewModel

        // Populate form if editing
        if let schema = schema {
            populateForm(from: schema)
        }
    }

    // MARK: - Public Methods

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["name"] = "Name is required"
        }

        // Validate schema JSON
        if schemaJSON.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["schema"] = "Schema is required"
        } else if !validateJSON() {
            validationErrors["schema"] = "Invalid JSON format"
        }

        return validationErrors.isEmpty
    }

    public func validateJSON() -> Bool {
        guard let data = schemaJSON.data(using: .utf8) else { return false }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func submit() async throws -> PositionSchema {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            // Parse JSON string directly to OpenAPIValueContainer map
            let data = schemaJSON.data(using: .utf8)!
            let convertedSchema = try JSONDecoder().decode(
                [String: OpenAPIRuntime.OpenAPIValueContainer].self,
                from: data
            )

            let result: PositionSchema
            if let existingSchema = schema {
                // Update
                let updateRequest = UpdatePositionSchemaRequest(
                    name: name,
                    schema: .init(additionalProperties: convertedSchema)
                )
                result = try await schemaService.updatePositionSchema(id: existingSchema.id, updateRequest)
                eventViewModel?.emit(.positionSchemaUpdated(id: result.id))
            } else {
                // Create
                let createRequest = NewPositionSchemaRequest(
                    name: name,
                    schema: .init(additionalProperties: convertedSchema)
                )
                result = try await schemaService.createPositionSchema(createRequest)
                eventViewModel?.emit(.positionSchemaCreated(id: result.id))
            }

            isSubmitting = false
            return result
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Private Methods

    private func populateForm(from schema: PositionSchema) {
        name = schema.name

        // Convert OpenAPIValueContainer to JSON-serializable dictionary
        var unwrappedDict: [String: Any] = [:]
        for (key, container) in schema.schema.additionalProperties {
            // Encode the container and decode back to Any
            if let jsonData = try? JSONEncoder().encode(container),
               let value = try? JSONSerialization.jsonObject(with: jsonData, options: [])
            {
                unwrappedDict[key] = value
            }
        }

        // Convert schema dictionary to JSON string
        if let data = try? JSONSerialization.data(withJSONObject: unwrappedDict, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8)
        {
            schemaJSON = jsonString
        }
    }
}
