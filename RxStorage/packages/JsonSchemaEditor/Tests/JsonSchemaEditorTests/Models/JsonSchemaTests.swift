//
//  JsonSchemaTests.swift
//  JsonSchemaEditorTests
//

import JSONSchema
@testable import JsonSchemaEditor
import Testing

@Suite("JsonSchema Model Tests")
struct JsonSchemaTests {
    @Test("PropertyType has all expected cases")
    func propertyTypeCases() {
        let allCases = PropertyType.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.string))
        #expect(allCases.contains(.number))
        #expect(allCases.contains(.integer))
        #expect(allCases.contains(.boolean))
        #expect(allCases.contains(.array))
    }

    @Test("RootSchemaType has all expected cases")
    func rootSchemaTypeCases() {
        let allCases = RootSchemaType.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.object))
        #expect(allCases.contains(.array))
        #expect(allCases.contains(.string))
    }

    @Test("PropertyType displayLabel is capitalized")
    func propertyTypeDisplayLabel() {
        #expect(PropertyType.string.displayLabel == "String")
        #expect(PropertyType.integer.displayLabel == "Integer")
    }

    @Test("RootSchemaType typeDescription is meaningful")
    func rootSchemaTypeDescription() {
        #expect(RootSchemaType.object.typeDescription.contains("properties"))
        #expect(RootSchemaType.array.typeDescription.contains("List") || RootSchemaType.array.typeDescription.contains("items"))
    }

    @Test("PropertyType schemaType conversion")
    func propertyTypeSchemaTypeConversion() {
        #expect(PropertyType.string.schemaType == .string)
        #expect(PropertyType.number.schemaType == .number)
        #expect(PropertyType.integer.schemaType == .integer)
        #expect(PropertyType.boolean.schemaType == .boolean)
        #expect(PropertyType.array.schemaType == .array)
    }

    @Test("PropertyType init from schemaType")
    func propertyTypeFromSchemaType() {
        #expect(PropertyType(schemaType: .string) == .string)
        #expect(PropertyType(schemaType: .number) == .number)
        #expect(PropertyType(schemaType: .object) == nil)
    }

    @Test("JSONSchema object factory method")
    func jsonSchemaObjectFactory() {
        let schema = JSONSchema.object(
            title: "Person",
            description: "A person object",
            properties: ["name": JSONSchema.string()],
            required: ["name"]
        )

        #expect(schema.type == .object)
        #expect(schema.title == "Person")
        #expect(schema.description == "A person object")
        #expect(schema.objectSchema?.properties?.count == 1)
        #expect(schema.objectSchema?.required == ["name"])
    }

    @Test("JSONSchema rootSchemaType for object")
    func jsonSchemaObjectRootType() {
        let schema = JSONSchema.object()
        #expect(schema.rootSchemaType == .object)
    }

    @Test("JSONSchema rootSchemaType for array")
    func jsonSchemaArrayRootType() {
        let schema = JSONSchema.array()
        #expect(schema.rootSchemaType == .array)
    }

    @Test("JSONSchema rootSchemaType for string")
    func jsonSchemaStringRootType() {
        let schema = JSONSchema.string()
        #expect(schema.rootSchemaType == .string)
    }

    @Test("JSONSchema emptyObject creates object schema")
    func jsonSchemaEmptyObject() {
        let schema = JSONSchema.emptyObject()
        #expect(schema.type == .object)
    }

    @Test("JSONSchema create method")
    func jsonSchemaCreate() {
        let objectSchema = JSONSchema.create(type: .object)
        #expect(objectSchema.type == .object)

        let stringSchema = JSONSchema.create(type: .string)
        #expect(stringSchema.type == .string)
    }

    @Test("PropertyItem initialization")
    func propertyItemInit() {
        let item = PropertyItem(
            key: "testKey",
            property: JSONSchema.boolean(),
            isRequired: true
        )

        #expect(item.key == "testKey")
        #expect(item.property.type == .boolean)
        #expect(item.isRequired == true)
        #expect(item.id != UUID()) // Has a valid ID
    }

    @Test("PropertyItem default values")
    func propertyItemDefaults() {
        let item = PropertyItem()
        #expect(item.key == "")
        #expect(item.property.type == .string)
        #expect(item.isRequired == false)
    }

    @Test("PropertyItem propertyType accessor")
    func propertyItemPropertyType() {
        var item = PropertyItem(property: JSONSchema.integer())
        #expect(item.propertyType == .integer)

        item.propertyType = .boolean
        #expect(item.property.type == .boolean)
    }

    @Test("PropertyItem propertyDescription accessor")
    func propertyItemPropertyDescription() {
        var item = PropertyItem(property: JSONSchema.string(description: "Test"))
        #expect(item.propertyDescription == "Test")

        item.propertyDescription = "Updated"
        #expect(item.property.description == "Updated")
    }
}
