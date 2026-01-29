//
//  JsonSchemaEditorViewModel.swift
//  JsonSchemaEditor
//

import Foundation
import SwiftUI
import JSONSchema

/// Editor tab modes
public enum EditorTab: String, CaseIterable, Sendable {
    case visual = "Visual Editor"
    case raw = "Raw JSON"
}

/// Actor-based state container for thread-safe state management
public actor SchemaEditorState {
    public var schemaType: RootSchemaType = .object
    public var items: [PropertyItem] = []
    public var rawJson: String = ""
    public var activeTab: EditorTab = .visual
    public var jsonError: String?
    public var title: String = ""
    public var schemaDescription: String = ""
    public var arrayItemsType: PropertyType = .string

    public init() {}

    public func update(
        schemaType: RootSchemaType? = nil,
        items: [PropertyItem]? = nil,
        rawJson: String? = nil,
        activeTab: EditorTab? = nil,
        jsonError: String?? = nil,
        title: String? = nil,
        schemaDescription: String? = nil,
        arrayItemsType: PropertyType? = nil
    ) {
        if let schemaType { self.schemaType = schemaType }
        if let items { self.items = items }
        if let rawJson { self.rawJson = rawJson }
        if let activeTab { self.activeTab = activeTab }
        if let jsonError { self.jsonError = jsonError }
        if let title { self.title = title }
        if let schemaDescription { self.schemaDescription = schemaDescription }
        if let arrayItemsType { self.arrayItemsType = arrayItemsType }
    }

    public func getSnapshot() -> StateSnapshot {
        StateSnapshot(
            schemaType: schemaType,
            items: items,
            rawJson: rawJson,
            activeTab: activeTab,
            jsonError: jsonError,
            title: title,
            schemaDescription: schemaDescription,
            arrayItemsType: arrayItemsType
        )
    }
}

/// Immutable snapshot of state for use in SwiftUI views
public struct StateSnapshot: Sendable {
    public let schemaType: RootSchemaType
    public let items: [PropertyItem]
    public let rawJson: String
    public let activeTab: EditorTab
    public let jsonError: String?
    public let title: String
    public let schemaDescription: String
    public let arrayItemsType: PropertyType
}

/// Main view model for the JSON Schema Editor
/// Uses @Observable for SwiftUI integration with @MainActor for thread safety
@Observable
@MainActor
public final class JsonSchemaEditorViewModel {
    // MARK: - Published Properties

    public var schemaType: RootSchemaType = .object
    public var items: [PropertyItem] = []
    public var rawJson: String = ""
    public var activeTab: EditorTab = .visual
    public var jsonError: String?
    public var title: String = ""
    public var schemaDescription: String = ""
    public var arrayItemsType: PropertyType = .string

    // MARK: - Private

    private var isSyncingFromValue = false

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
            // Object schemas store title at top level
            title = schema.title ?? ""
            items = SchemaConversion.schemaToPropertyItems(schema)
        case .array:
            // Array schemas store title inside arraySchema
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

        rawJson = SchemaJSON.stringify(schema)
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

    /// Handle raw JSON text change
    public func handleRawJsonChange(_ newJson: String) {
        rawJson = newJson

        guard !newJson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            jsonError = nil
            return
        }

        switch SchemaJSON.parse(newJson) {
        case .success(let schema):
            jsonError = nil
            isSyncingFromValue = true
            loadSchema(schema)
            isSyncingFromValue = false
        case .failure(let error):
            jsonError = error.localizedDescription
        }
    }

    /// Handle tab change
    public func handleTabChange(_ newTab: EditorTab) {
        guard newTab != activeTab else { return }

        // If switching from raw to visual with an error, prevent switch
        if activeTab == .raw && newTab == .visual && jsonError != nil {
            return
        }

        // Sync data before switching
        if activeTab == .visual && newTab == .raw {
            // Visual -> Raw: update raw JSON
            if let schema = buildSchema() {
                rawJson = SchemaJSON.stringify(schema)
            }
        }

        activeTab = newTab
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
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
    }

    /// Move a property up
    public func movePropertyUp(at index: Int) {
        guard index > 0 && index < items.count else { return }
        items.swapAt(index, index - 1)
    }

    /// Move a property down
    public func movePropertyDown(at index: Int) {
        guard index >= 0 && index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
    }

    /// Update a property at index
    public func updateProperty(at index: Int, with item: PropertyItem) {
        guard index >= 0 && index < items.count else { return }
        items[index] = item
    }

    // MARK: - Private Methods

    private func reset() {
        schemaType = .object
        items = []
        rawJson = ""
        jsonError = nil
        title = ""
        schemaDescription = ""
        arrayItemsType = .string
    }
}
