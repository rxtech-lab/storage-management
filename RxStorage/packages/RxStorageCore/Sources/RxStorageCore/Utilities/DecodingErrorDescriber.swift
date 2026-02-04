//
//  DecodingErrorDescriber.swift
//  RxStorageCore
//
//  Utility for describing DecodingErrors with detailed context for logging
//

import Foundation

/// Describes a DecodingError with useful context for logging and debugging.
///
/// This function provides detailed information about where the decoding failed,
/// including the coding path and any relevant debug descriptions.
///
/// ## Example Output
///
/// - Type mismatch: `"Type mismatch: expected Int at items.0.id, The data couldn't be read because it isn't in the correct format."`
/// - Key not found: `"Key not found: 'title' at items.0, No value associated with key 'title'"`
/// - Value not found: `"Value not found: expected String at items.0.name, Expected String value but found null instead."`
/// - Data corrupted: `"Data corrupted at items.0: Invalid JSON structure"`
///
/// - Parameter error: The `DecodingError` to describe
/// - Returns: A human-readable description of the error with context
public func describeDecodingError(_ error: DecodingError) -> String {
    switch error {
    case let .typeMismatch(type, context):
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "Type mismatch: expected \(type) at \(path.isEmpty ? "root" : path), \(context.debugDescription)"

    case let .valueNotFound(type, context):
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "Value not found: expected \(type) at \(path.isEmpty ? "root" : path), \(context.debugDescription)"

    case let .keyNotFound(key, context):
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "Key not found: '\(key.stringValue)' at \(path.isEmpty ? "root" : path), \(context.debugDescription)"

    case let .dataCorrupted(context):
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "Data corrupted at \(path.isEmpty ? "root" : path): \(context.debugDescription)"

    @unknown default:
        return "Unknown decoding error: \(error.localizedDescription)"
    }
}
