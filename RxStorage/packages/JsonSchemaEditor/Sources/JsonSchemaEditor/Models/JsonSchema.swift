//
//  JsonSchema.swift
//  JsonSchemaEditor
//
//  This file re-exports types from the swift-json-schema package
//  and provides compatibility typealiases
//

import Foundation
@_exported import JSONSchema

/// Typealias for backward compatibility - use JSONSchema from the package
public typealias JsonSchema = JSONSchema

/// Extension to add convenience methods to JSONSchema
public extension JSONSchema {
    /// Get the root schema type for visual editor UI
    var rootSchemaType: RootSchemaType? {
        RootSchemaType(schemaType: type)
    }

    /// Create an empty object schema
    static func emptyObject() -> JSONSchema {
        .object()
    }

    /// Create an empty string schema
    static func emptyString() -> JSONSchema {
        .string()
    }

    /// Create a schema from a root type
    static func create(type rootType: RootSchemaType, title: String? = nil, schemaDescription: String? = nil) -> JSONSchema {
        switch rootType {
        case .object:
            return JSONSchema.object(title: title, description: schemaDescription)
        case .array:
            return JSONSchema.array(title: title, description: schemaDescription, items: JSONSchema.string())
        case .string:
            return JSONSchema.string(description: schemaDescription)
        case .number:
            return JSONSchema.number(description: schemaDescription)
        case .integer:
            return JSONSchema.integer(description: schemaDescription)
        case .boolean:
            return JSONSchema.boolean(description: schemaDescription)
        }
    }
}
