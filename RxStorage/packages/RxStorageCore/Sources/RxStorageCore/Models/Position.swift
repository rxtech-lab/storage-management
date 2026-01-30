//
//  Position.swift
//  RxStorageCore
//
//  Position data model for item positions
//

import Foundation

/// Position data associated with an item
public struct Position: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let itemId: Int
    public let positionSchemaId: Int
    public let data: [String: AnyCodable]
    public let createdAt: Date
    public let updatedAt: Date
    public var positionSchema: PositionSchema?

    public init(
        id: Int,
        itemId: Int,
        positionSchemaId: Int,
        data: [String: AnyCodable],
        createdAt: Date,
        updatedAt: Date,
        positionSchema: PositionSchema? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.positionSchemaId = positionSchemaId
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.positionSchema = positionSchema
    }

    // Custom Hashable implementation since positionSchema is optional
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(itemId)
        hasher.combine(positionSchemaId)
    }

    public static func == (lhs: Position, rhs: Position) -> Bool {
        lhs.id == rhs.id &&
            lhs.itemId == rhs.itemId &&
            lhs.positionSchemaId == rhs.positionSchemaId
    }
}

/// Position data for creating (no id, itemId handled by API)
public struct NewPositionData: Codable, Sendable {
    public let positionSchemaId: Int
    public let data: [String: AnyCodable]

    public init(positionSchemaId: Int, data: [String: AnyCodable]) {
        self.positionSchemaId = positionSchemaId
        self.data = data
    }
}

/// Local pending position for UI state (includes schema for display)
public struct PendingPosition: Identifiable, Sendable {
    public let id: UUID
    public let positionSchemaId: Int
    public let schema: PositionSchema
    public let data: [String: AnyCodable]

    public init(positionSchemaId: Int, schema: PositionSchema, data: [String: AnyCodable]) {
        self.id = UUID()
        self.positionSchemaId = positionSchemaId
        self.schema = schema
        self.data = data
    }

    /// Convert to API request format
    public var asNewPositionData: NewPositionData {
        NewPositionData(positionSchemaId: positionSchemaId, data: data)
    }
}
