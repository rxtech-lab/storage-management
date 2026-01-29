//
//  JsonSchemaEditorViewModelTests.swift
//  JsonSchemaEditorTests
//

import Testing
import JSONSchema
@testable import JsonSchemaEditor

@Suite("JsonSchemaEditorViewModel Tests")
struct JsonSchemaEditorViewModelTests {

    @Test("Initial state with nil schema")
    @MainActor
    func testInitialStateWithNilSchema() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)

        #expect(sut.schemaType == .object)
        #expect(sut.items.isEmpty)
        #expect(sut.rawJson.isEmpty)
        #expect(sut.activeTab == .visual)
        #expect(sut.jsonError == nil)
    }

    @Test("Load existing object schema")
    @MainActor
    func testLoadExistingObjectSchema() async {
        let schema = JSONSchema.object(
            title: "Test",
            properties: [
                "name": JSONSchema.string()
            ],
            required: ["name"]
        )

        let sut = JsonSchemaEditorViewModel(schema: schema)

        #expect(sut.schemaType == .object)
        #expect(sut.title == "Test")
        #expect(sut.items.count == 1)
        #expect(sut.items[0].key == "name")
        #expect(sut.items[0].isRequired == true)
    }

    @Test("Load array schema")
    @MainActor
    func testLoadArraySchema() async {
        let schema = JSONSchema.array(
            title: "List",
            items: JSONSchema.integer()
        )

        let sut = JsonSchemaEditorViewModel(schema: schema)

        #expect(sut.schemaType == .array)
        #expect(sut.title == "List")
        #expect(sut.arrayItemsType == .integer)
        #expect(sut.items.isEmpty)
    }

    @Test("Add property creates new item")
    @MainActor
    func testAddProperty() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)

        sut.addProperty()

        #expect(sut.items.count == 1)
        #expect(sut.items[0].key == "property")
        #expect(sut.items[0].property.type == .string)
    }

    @Test("Add property generates unique key")
    @MainActor
    func testAddPropertyGeneratesUniqueKey() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)

        sut.addProperty()
        sut.addProperty()
        sut.addProperty()

        let keys = sut.items.map { $0.key }
        #expect(Set(keys).count == 3) // All unique
        #expect(keys.contains("property"))
        #expect(keys.contains("property_1"))
        #expect(keys.contains("property_2"))
    }

    @Test("Delete property removes item")
    @MainActor
    func testDeleteProperty() async {
        let schema = JSONSchema.object(
            properties: [
                "name": JSONSchema.string(),
                "age": JSONSchema.integer()
            ]
        )
        let sut = JsonSchemaEditorViewModel(schema: schema)

        sut.deleteProperty(at: 0)

        #expect(sut.items.count == 1)
    }

    @Test("Delete property at invalid index does nothing")
    @MainActor
    func testDeletePropertyInvalidIndex() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.addProperty()

        sut.deleteProperty(at: 5) // Invalid index

        #expect(sut.items.count == 1) // Still has the item
    }

    @Test("Move property up changes order")
    @MainActor
    func testMovePropertyUp() async {
        let schema = JSONSchema.object(
            properties: [
                "first": JSONSchema.string(),
                "second": JSONSchema.string()
            ]
        )
        let sut = JsonSchemaEditorViewModel(schema: schema)

        // Find the index of "second" (order may vary due to dictionary)
        let secondIndex = sut.items.firstIndex { $0.key == "second" } ?? 1
        let firstIndex = sut.items.firstIndex { $0.key == "first" } ?? 0

        if secondIndex > firstIndex {
            sut.movePropertyUp(at: secondIndex)
            #expect(sut.items[firstIndex].key == "second")
        }
    }

    @Test("Move property down changes order")
    @MainActor
    func testMovePropertyDown() async {
        let schema = JSONSchema.object(
            properties: [
                "first": JSONSchema.string(),
                "second": JSONSchema.string()
            ]
        )
        let sut = JsonSchemaEditorViewModel(schema: schema)

        // Find the index of "first" (order may vary due to dictionary)
        let firstIndex = sut.items.firstIndex { $0.key == "first" } ?? 0

        if firstIndex < sut.items.count - 1 {
            sut.movePropertyDown(at: firstIndex)
            #expect(sut.items[firstIndex].key != "first")
        }
    }

    @Test("Handle type change to array")
    @MainActor
    func testHandleTypeChangeToArray() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.addProperty()
        sut.title = "Test"

        sut.handleTypeChange(.array)

        #expect(sut.schemaType == .array)
        #expect(sut.title == "Test") // Title preserved
        #expect(sut.items.isEmpty) // Properties cleared for non-object types
    }

    @Test("Build schema returns correct structure")
    @MainActor
    func testBuildSchema() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.addProperty()
        sut.items[0].key = "testField"
        sut.items[0].propertyType = .string
        sut.items[0].isRequired = true
        sut.title = "Test Schema"

        let schema = sut.buildSchema()

        #expect(schema?.type == .object)
        #expect(schema?.title == "Test Schema")
        #expect(schema?.objectSchema?.properties?["testField"] != nil)
        #expect(schema?.objectSchema?.required?.contains("testField") == true)
    }

    @Test("Build array schema")
    @MainActor
    func testBuildArraySchema() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.handleTypeChange(.array)
        sut.arrayItemsType = .integer
        sut.title = "Numbers"

        let schema = sut.buildSchema()

        #expect(schema?.type == .array)
        // For arrays, title is stored in arraySchema
        #expect(schema?.arraySchema?.title == "Numbers")
        #expect(schema?.arraySchema?.items?.type == .integer)
    }

    @Test("Raw JSON parsing updates items")
    @MainActor
    func testRawJsonParsing() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)

        sut.handleRawJsonChange("""
        {
            "type": "object",
            "properties": {
                "email": { "type": "string", "title": "Email Address" }
            }
        }
        """)

        #expect(sut.jsonError == nil)
        #expect(sut.items.count == 1)
        #expect(sut.items[0].key == "email")
    }

    @Test("Invalid JSON sets error")
    @MainActor
    func testInvalidJsonSetsError() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)

        sut.handleRawJsonChange("{invalid json}")

        #expect(sut.jsonError != nil)
    }

    @Test("Empty JSON clears error")
    @MainActor
    func testEmptyJsonClearsError() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.handleRawJsonChange("{invalid}")
        #expect(sut.jsonError != nil)

        sut.handleRawJsonChange("")
        #expect(sut.jsonError == nil)
    }

    @Test("Tab change from visual to raw updates JSON")
    @MainActor
    func testTabChangeVisualToRaw() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.addProperty()
        sut.items[0].key = "test"

        sut.handleTabChange(.raw)

        #expect(sut.activeTab == .raw)
        #expect(sut.rawJson.contains("test"))
    }

    @Test("Tab change blocked with JSON error")
    @MainActor
    func testTabChangeBlockedWithError() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.activeTab = .raw
        sut.handleRawJsonChange("{invalid}")

        sut.handleTabChange(.visual)

        #expect(sut.activeTab == .raw) // Tab change blocked
    }

    @Test("Update property at index")
    @MainActor
    func testUpdatePropertyAtIndex() async {
        let sut = JsonSchemaEditorViewModel(schema: nil)
        sut.addProperty()

        var updatedItem = sut.items[0]
        updatedItem.key = "updated"
        updatedItem.isRequired = true

        sut.updateProperty(at: 0, with: updatedItem)

        #expect(sut.items[0].key == "updated")
        #expect(sut.items[0].isRequired == true)
    }
}
