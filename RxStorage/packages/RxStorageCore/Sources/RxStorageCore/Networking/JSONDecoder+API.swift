//
//  JSONDecoder+API.swift
//  RxStorageCore
//
//  Shared JSON decoder configuration for API responses
//

import Foundation

extension JSONDecoder {
    /// Creates a JSONDecoder configured for API responses with ISO8601 date decoding
    /// Supports both fractional seconds (e.g., "2026-01-29T05:34:44.000Z")
    /// and standard ISO8601 (e.g., "2026-01-29T05:34:44Z")
    public static func apiDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try with fractional seconds first
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractional.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601 without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
