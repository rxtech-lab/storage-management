//
//  PropertyType.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// Supported property types for schema fields (subset for property editing)
public enum PropertyType: String, CaseIterable, Codable, Sendable {
    case string
    case number
    case integer
    case boolean
    case array

    public var displayLabel: String {
        rawValue.capitalized
    }

    /// Convert to JSONSchema.SchemaType
    public var schemaType: JSONSchema.SchemaType {
        switch self {
        case .string: return .string
        case .number: return .number
        case .integer: return .integer
        case .boolean: return .boolean
        case .array: return .array
        }
    }

    /// Create from JSONSchema.SchemaType
    public init?(schemaType: JSONSchema.SchemaType) {
        switch schemaType {
        case .string: self = .string
        case .number: self = .number
        case .integer: self = .integer
        case .boolean: self = .boolean
        case .array: self = .array
        default: return nil
        }
    }
}
