//
//  SchemaValidation.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// Result of a validation operation
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let error: String?

    public init(isValid: Bool, error: String? = nil) {
        self.isValid = isValid
        self.error = error
    }

    public static let valid = ValidationResult(isValid: true)

    public static func invalid(_ error: String) -> ValidationResult {
        ValidationResult(isValid: false, error: error)
    }
}

/// Schema validation utilities
public enum SchemaValidation {
    /// Property key validation regex pattern
    /// Must start with letter or underscore, followed by letters, numbers, or underscores
    private static let propertyKeyPattern = "^[a-zA-Z_][a-zA-Z0-9_]*$"

    /// Validate a property key
    public static func validatePropertyKey(_ key: String) -> ValidationResult {
        guard !key.isEmpty else {
            return .invalid("Property name is required")
        }

        guard let regex = try? NSRegularExpression(pattern: propertyKeyPattern),
              regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil
        else {
            return .invalid("Must start with a letter or underscore, and contain only letters, numbers, and underscores")
        }

        return .valid
    }

    /// Check if a key is unique among existing keys
    public static func isKeyUnique(
        _ key: String,
        existingKeys: [String],
        excluding currentKey: String? = nil
    ) -> Bool {
        let keysToCheck = currentKey.map { current in existingKeys.filter { $0 != current } } ?? existingKeys
        return !keysToCheck.contains(key)
    }

    /// Validate a complete schema structure
    public static func validateSchema(_ schema: JSONSchema) -> ValidationResult {
        guard schema.type == .object else {
            // Non-object schemas are valid by default
            return .valid
        }

        guard let objectSchema = schema.objectSchema,
              let properties = objectSchema.properties
        else {
            return .valid
        }

        // Validate all property keys
        for key in properties.keys {
            let result = validatePropertyKey(key)
            if !result.isValid {
                return .invalid("Invalid property key '\(key)': \(result.error ?? "")")
            }
        }

        // Validate required fields exist in properties
        if let required = objectSchema.required {
            for requiredKey in required {
                if properties[requiredKey] == nil {
                    return .invalid("Required property '\(requiredKey)' not found in properties")
                }
            }
        }

        return .valid
    }
}
