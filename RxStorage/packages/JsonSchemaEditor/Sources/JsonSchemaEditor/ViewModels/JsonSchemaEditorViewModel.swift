//
//  JsonSchemaEditorViewModel.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema
import SwiftUI

/// Main view model for the JSON Schema Editor
/// Uses @Observable for SwiftUI integration with @MainActor for thread safety
@Observable
@MainActor
public final class JsonSchemaEditorViewModel {
    // MARK: - Published Properties

    public var schemaType: RootSchemaType = .object
    public var items: [PropertyItem] = []
    public var title: String = ""
    public var schemaDescription: String = ""
    public var arrayItemsType: PropertyType = .string

    // MARK: - Initialization

    public init(schema: JSONSchema? = nil) {
        if let schema {
            loadSchema(schema)
        }
    }

    // MARK: - Public Methods

    /// Load a schema into the editor
    public func loadSchema(_ schema: JSONSchema?) {
        guard let schema else {
            reset()
            return
        }

        schemaType = schema.rootSchemaType ?? .object
        schemaDescription = schema.description ?? ""

        switch schema.type {
        case .object:
            title = schema.title ?? ""
            items = SchemaConversion.schemaToPropertyItems(schema)
        case .array:
            if let arraySchema = schema.arraySchema {
                title = arraySchema.title ?? ""
                if let itemsSchema = arraySchema.items {
                    arrayItemsType = PropertyType(schemaType: itemsSchema.type) ?? .string
                } else {
                    arrayItemsType = .string
                }
            } else {
                title = ""
                arrayItemsType = .string
            }
            items = []
        default:
            title = schema.title ?? ""
            items = []
        }
    }

    /// Build the current state into a JSONSchema
    public func buildSchema() -> JSONSchema? {
        switch schemaType {
        case .object:
            return SchemaConversion.propertyItemsToSchema(
                items,
                title: title.isEmpty ? nil : title,
                description: schemaDescription.isEmpty ? nil : schemaDescription
            )

        case .array:
            return JSONSchema.array(
                title: title.isEmpty ? nil : title,
                description: schemaDescription.isEmpty ? nil : schemaDescription,
                items: JSONSchema.create(type: RootSchemaType(rawValue: arrayItemsType.rawValue) ?? .string)
            )

        case .string, .number, .integer, .boolean:
            return JSONSchema.create(
                type: schemaType,
                schemaDescription: schemaDescription.isEmpty ? nil : schemaDescription
            )
        }
    }

    /// Handle schema type change
    public func handleTypeChange(_ newType: RootSchemaType) {
        guard newType != schemaType else { return }

        let currentSchema = buildSchema()
        let newSchema = SchemaConversion.convertSchemaType(currentSchema, to: newType)

        schemaType = newType
        loadSchema(newSchema)
    }

    // MARK: - Property Management

    /// Add a new property
    public func addProperty() {
        let existingKeys = items.map { $0.key }
        let newItem = SchemaConversion.createPropertyItem(existingKeys: existingKeys)
        items.append(newItem)
    }

    /// Delete a property at index
    public func deleteProperty(at index: Int) {
        guard index >= 0, index < items.count else { return }
        items.remove(at: index)
    }

    /// Move a property up
    public func movePropertyUp(at index: Int) {
        guard index > 0, index < items.count else { return }
        items.swapAt(index, index - 1)
    }

    /// Move a property down
    public func movePropertyDown(at index: Int) {
        guard index >= 0, index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
    }

    /// Update a property at index
    public func updateProperty(at index: Int, with item: PropertyItem) {
        guard index >= 0, index < items.count else { return }
        items[index] = item
    }

    // MARK: - Private Methods

    private func reset() {
        schemaType = .object
        items = []
        title = ""
        schemaDescription = ""
        arrayItemsType = .string
    }
}
