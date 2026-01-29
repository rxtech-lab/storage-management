//
//  RootSchemaType.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// Supported root schema types (includes object in addition to property types)
public enum RootSchemaType: String, CaseIterable, Codable, Sendable {
    case object
    case array
    case string
    case number
    case integer
    case boolean

    public var displayLabel: String {
        rawValue.capitalized
    }

    public var typeDescription: String {
        switch self {
        case .object: return "Schema with named properties"
        case .array: return "List of items"
        case .string: return "Text value"
        case .number: return "Numeric value (decimal)"
        case .integer: return "Numeric value (whole number)"
        case .boolean: return "True/false value"
        }
    }

    /// Convert to JSONSchema.SchemaType
    public var schemaType: JSONSchema.SchemaType {
        switch self {
        case .object: return .object
        case .array: return .array
        case .string: return .string
        case .number: return .number
        case .integer: return .integer
        case .boolean: return .boolean
        }
    }

    /// Create from JSONSchema.SchemaType
    public init?(schemaType: JSONSchema.SchemaType) {
        switch schemaType {
        case .object: self = .object
        case .array: self = .array
        case .string: self = .string
        case .number: self = .number
        case .integer: self = .integer
        case .boolean: self = .boolean
        default: return nil
        }
    }
}
