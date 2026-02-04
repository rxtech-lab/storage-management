//
//  SchemaConversionTests.swift
//  JsonSchemaEditorTests
//

import JSONSchema
@testable import JsonSchemaEditor
import Testing

@Suite("Schema Conversion Tests")
struct SchemaConversionTests {
    @Test("Schema to property items with object schema")
    func testSchemaToPropertyItems() {
        let schema = JSONSchema.object(
            properties: [
                "name": JSONSchema.string(),
                "age": JSONSchema.integer(),
            ],
            required: ["name"]
        )

        let items = SchemaConversion.schemaToPropertyItems(schema)

        #expect(items.count == 2)
        let nameItem = items.first { $0.key == "name" }
        #expect(nameItem?.isRequired == true)
        #expect(nameItem?.property.type == .string)
    }

    @Test("Schema to property items with nil returns empty array")
    func schemaToPropertyItemsNil() {
        let items = SchemaConversion.schemaToPropertyItems(nil)
        #expect(items.isEmpty)
    }

    @Test("Schema to property items with non-object returns empty array")
    func schemaToPropertyItemsNonObject() {
        let schema = JSONSchema.array()
        let items = SchemaConversion.schemaToPropertyItems(schema)
        #expect(items.isEmpty)
    }

    @Test("Property items to schema")
    func testPropertyItemsToSchema() {
        let items = [
            PropertyItem(key: "name", property: JSONSchema.string(), isRequired: true),
            PropertyItem(key: "age", property: JSONSchema.integer(), isRequired: false),
        ]

        let schema = SchemaConversion.propertyItemsToSchema(items, title: "Test", description: "Test schema")

        #expect(schema.title == "Test")
        #expect(schema.description == "Test schema")
        #expect(schema.objectSchema?.properties?.count == 2)
        #expect(schema.objectSchema?.required == ["name"])
    }

    @Test("Create schema of type object")
    func createSchemaOfTypeObject() {
        let schema = SchemaConversion.createSchemaOfType(.object)
        #expect(schema.type == .object)
    }

    @Test("Create schema of type array")
    func createSchemaOfTypeArray() {
        let schema = SchemaConversion.createSchemaOfType(.array)
        #expect(schema.type == .array)
    }

    @Test("Create schema of type string")
    func createSchemaOfTypeString() {
        let schema = SchemaConversion.createSchemaOfType(.string)
        #expect(schema.type == .string)
    }

    @Test("Convert schema type preserves description")
    func convertSchemaTypePreservesMetadata() {
        let original = JSONSchema.object(title: "Original", description: "Description")
        let converted = SchemaConversion.convertSchemaType(original, to: .array)

        // For arrays, title is stored in arraySchema
        #expect(converted.arraySchema?.title == "Original")
        #expect(converted.description == "Description")
        #expect(converted.type == .array)
    }

    @Test("Create property item with unique key")
    func testCreatePropertyItem() {
        let existingKeys = ["property", "property_1"]
        let newItem = SchemaConversion.createPropertyItem(existingKeys: existingKeys)

        #expect(newItem.key == "property_2")
        #expect(newItem.property.type == .string)
    }

    @Test("Generate unique key with no conflicts")
    func generateUniqueKeyNoConflicts() {
        let uniqueKey = SchemaConversion.generateUniqueKey(existingKeys: [])
        #expect(uniqueKey == "property")
    }

    @Test("Generate unique key with conflicts")
    func generateUniqueKeyWithConflicts() {
        let uniqueKey = SchemaConversion.generateUniqueKey(existingKeys: ["property", "property_1", "property_2"])
        #expect(uniqueKey == "property_3")
    }
}
