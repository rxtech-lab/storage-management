//
//  ContentSchema.swift
//  RxStorageCore
//
//  Content schema model for dynamic forms (file/image/video types)
//

import Foundation

/// Content schema defining structure for content types (file, image, video)
/// Unlike PositionSchema which has user-defined schemas, ContentSchema uses predefined types
public struct ContentSchema: Codable, Identifiable, Hashable, Sendable {
    public let type: String      // "file", "image", "video"
    public let name: String      // Display name (e.g., "File", "Image", "Video")
    public let schema: [String: AnyCodable]  // JSON Schema for form rendering

    /// Use type as the identifier since content schemas are predefined by type
    public var id: String { type }

    public init(
        type: String,
        name: String,
        schema: [String: AnyCodable]
    ) {
        self.type = type
        self.name = name
        self.schema = schema
    }
}
