//
//  PropertyItem.swift
//  JsonSchemaEditor
//

import Foundation
import JSONSchema

/// Internal representation of a property with its key for editing
public struct PropertyItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var key: String
    public var property: JSONSchema
    public var isRequired: Bool

    public init(
        id: UUID = UUID(),
        key: String = "",
        property: JSONSchema = JSONSchema.string(),
        isRequired: Bool = false
    ) {
        self.id = id
        self.key = key
        self.property = property
        self.isRequired = isRequired
    }

    public static func == (lhs: PropertyItem, rhs: PropertyItem) -> Bool {
        lhs.id == rhs.id &&
            lhs.key == rhs.key &&
            lhs.isRequired == rhs.isRequired &&
            lhs.property.title == rhs.property.title &&
            lhs.property.type == rhs.property.type &&
            lhs.property.description == rhs.property.description
    }

    // MARK: - Mutable Accessors (create new JSONSchema when setting)

    /// Property type as PropertyType enum for UI
    public var propertyType: PropertyType {
        get { PropertyType(schemaType: property.type) ?? .string }
        set { property = createSchema(type: newValue) }
    }

    /// Property title for UI (read-only, factory methods don't support title for primitive types)
    public var propertyTitle: String {
        property.title ?? ""
    }

    /// Property description for UI
    public var propertyDescription: String {
        get { property.description ?? "" }
        set { property = createSchema(description: newValue.isEmpty ? nil : newValue) }
    }

    /// Array items type for UI
    public var arrayItemsType: PropertyType {
        get {
            guard property.type == .array,
                  let items = property.arraySchema?.items
            else {
                return .string
            }
            return PropertyType(schemaType: items.type) ?? .string
        }
        set {
            guard property.type == .array else { return }
            property = JSONSchema.array(
                description: property.description,
                items: JSONSchema.create(type: RootSchemaType(rawValue: newValue.rawValue) ?? .string)
            )
        }
    }

    // MARK: - Private Helpers

    private func createSchema(
        type newType: PropertyType? = nil,
        description newDescription: String?? = nil
    ) -> JSONSchema {
        let type = newType ?? propertyType
        let description: String? = newDescription ?? property.description

        switch type {
        case .string:
            return JSONSchema.string(description: description)
        case .number:
            return JSONSchema.number(description: description)
        case .integer:
            return JSONSchema.integer(description: description)
        case .boolean:
            return JSONSchema.boolean(description: description)
        case .array:
            return JSONSchema.array(
                description: description,
                items: property.arraySchema?.items ?? JSONSchema.string()
            )
        }
    }
}
