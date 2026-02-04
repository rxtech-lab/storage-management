//
//  SchemaConversion.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// Schema conversion utilities
public enum SchemaConversion {
    /// Convert JSONSchema to PropertyItem array (for visual editor)
    public static func schemaToPropertyItems(_ schema: JSONSchema?) -> [PropertyItem] {
        guard let schema = schema,
              schema.type == .object,
              let objectSchema = schema.objectSchema,
              let properties = objectSchema.properties
        else {
            return []
        }

        let requiredSet = Set(objectSchema.required ?? [])

        // Sort keys to maintain consistent order
        let sortedKeys = properties.keys.sorted()

        return sortedKeys.compactMap { key -> PropertyItem? in
            guard let property = properties[key] else { return nil }
            return PropertyItem(
                key: key,
                property: property,
                isRequired: requiredSet.contains(key)
            )
        }
    }

    /// Convert PropertyItem array back to JSONSchema object
    public static func propertyItemsToSchema(
        _ items: [PropertyItem],
        title: String? = nil,
        description: String? = nil
    ) -> JSONSchema {
        var properties: [String: JSONSchema] = [:]
        var required: [String] = []

        for item in items {
            guard !item.key.isEmpty else { continue }
            properties[item.key] = item.property
            if item.isRequired {
                required.append(item.key)
            }
        }

        return JSONSchema.object(
            title: title,
            description: description,
            properties: properties.isEmpty ? nil : properties,
            required: required.isEmpty ? nil : required
        )
    }

    /// Create an empty schema of the specified type
    public static func createSchemaOfType(_ type: RootSchemaType) -> JSONSchema {
        JSONSchema.create(type: type)
    }

    /// Convert schema to a different type, preserving common fields like title and description
    public static func convertSchemaType(_ schema: JSONSchema?, to newType: RootSchemaType) -> JSONSchema {
        let title = schema?.title
        let description = schema?.description

        return JSONSchema.create(type: newType, title: title, schemaDescription: description)
    }

    /// Create a new property item with a unique key
    public static func createPropertyItem(existingKeys: [String]) -> PropertyItem {
        let uniqueKey = generateUniqueKey(existingKeys: existingKeys)
        return PropertyItem(
            key: uniqueKey,
            property: JSONSchema.string(),
            isRequired: false
        )
    }

    /// Generate a unique property key
    public static func generateUniqueKey(existingKeys: [String], baseName: String = "property") -> String {
        if !existingKeys.contains(baseName) {
            return baseName
        }

        var counter = 1
        while existingKeys.contains("\(baseName)_\(counter)") {
            counter += 1
        }

        return "\(baseName)_\(counter)"
    }

    /// Move an item in an array
    public static func moveArrayItem<T>(_ array: inout [T], from: Int, to: Int) {
        guard from >= 0, from < array.count, to >= 0, to < array.count, from != to else {
            return
        }

        let item = array.remove(at: from)
        array.insert(item, at: to)
    }
}
