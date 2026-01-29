//
//  SchemaJSON.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// JSON parsing error types
public enum SchemaParseError: Error, LocalizedError, Sendable {
    case invalidJSON(String)
    case invalidSchema(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .invalidSchema(let message):
            return "Invalid schema: \(message)"
        }
    }
}

/// JSON parsing and stringification utilities
public enum SchemaJSON {
    /// Parse a JSON string into a JSONSchema
    public static func parse(_ jsonString: String) -> Result<JSONSchema, SchemaParseError> {
        guard !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidJSON("Empty JSON string"))
        }

        do {
            let schema = try JSONSchema(jsonString: jsonString)
            return .success(schema)
        } catch let decodingError as DecodingError {
            let message = parseDecodingError(decodingError)
            return .failure(.invalidSchema(message))
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    /// Convert a JSONSchema to a formatted JSON string
    public static func stringify(_ schema: JSONSchema?, prettyPrint: Bool = true) -> String {
        guard let schema = schema else {
            return ""
        }

        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        do {
            let data = try encoder.encode(schema)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    /// Parse JSON string to dictionary for validation
    public static func parseToDict(_ jsonString: String) -> Result<[String: Any], SchemaParseError> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(.invalidJSON("Could not convert string to data"))
        }

        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.invalidSchema("JSON must be an object"))
            }
            return .success(dict)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    /// Helper to parse DecodingError into readable message
    private static func parseDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required key: \(key.stringValue)"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
        case .valueNotFound(let type, let context):
            return "Value not found for \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }
}
