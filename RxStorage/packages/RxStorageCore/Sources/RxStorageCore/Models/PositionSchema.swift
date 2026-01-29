//
//  PositionSchema.swift
//  RxStorageCore
//
//  Position schema model for dynamic forms
//

import Foundation

/// Position schema defining structure for item positions
public struct PositionSchema: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let schema: [String: AnyCodable]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: Int,
        name: String,
        schema: [String: AnyCodable],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.schema = schema
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Request body for creating a new position schema
public struct NewPositionSchemaRequest: Codable, Sendable {
    public let name: String
    public let schema: [String: AnyCodable]

    public init(name: String, schema: [String: AnyCodable]) {
        self.name = name
        self.schema = schema
    }
}

/// Request body for updating a position schema
public typealias UpdatePositionSchemaRequest = NewPositionSchemaRequest

/// Type-erased wrapper for JSON values
public struct AnyCodable: Codable, Hashable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch value {
        case let bool as Bool:
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(int)
        case let double as Double:
            hasher.combine(double)
        case let string as String:
            hasher.combine(string)
        default:
            break
        }
    }
}
