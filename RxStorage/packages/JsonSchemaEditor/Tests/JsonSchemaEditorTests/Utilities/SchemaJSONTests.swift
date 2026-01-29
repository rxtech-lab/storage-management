//
//  SchemaJSONTests.swift
//  JsonSchemaEditorTests
//

import Testing
import JSONSchema
@testable import JsonSchemaEditor

@Suite("Schema JSON Tests")
struct SchemaJSONTests {

    @Test("Parse valid object schema JSON")
    func testParseValidObjectSchema() {
        let json = """
        {
            "type": "object",
            "title": "Test",
            "properties": {
                "name": { "type": "string" }
            }
        }
        """

        let result = SchemaJSON.parse(json)

        switch result {
        case .success(let schema):
            #expect(schema.type == .object)
            #expect(schema.title == "Test")
        case .failure(let error):
            Issue.record("Parsing failed: \(error)")
        }
    }

    @Test("Parse valid array schema JSON")
    func testParseValidArraySchema() {
        let json = """
        {
            "type": "array",
            "items": { "type": "string" }
        }
        """

        let result = SchemaJSON.parse(json)

        switch result {
        case .success(let schema):
            #expect(schema.type == .array)
        case .failure(let error):
            Issue.record("Parsing failed: \(error)")
        }
    }

    @Test("Parse valid primitive schema JSON")
    func testParsePrimitiveSchema() {
        let json = """
        {
            "type": "string",
            "title": "Simple String"
        }
        """

        let result = SchemaJSON.parse(json)

        switch result {
        case .success(let schema):
            #expect(schema.type == .string)
            #expect(schema.title == "Simple String")
        case .failure(let error):
            Issue.record("Parsing failed: \(error)")
        }
    }

    @Test("Parse invalid JSON returns error")
    func testParseInvalidJSON() {
        let json = "{ invalid json }"

        let result = SchemaJSON.parse(json)

        switch result {
        case .success:
            Issue.record("Should have failed")
        case .failure:
            // Expected
            break
        }
    }

    @Test("Parse empty JSON returns error")
    func testParseEmptyJSON() {
        let json = ""

        let result = SchemaJSON.parse(json)

        switch result {
        case .success:
            Issue.record("Should have failed")
        case .failure(let error):
            #expect(error.localizedDescription.contains("Empty"))
        }
    }

    @Test("Stringify object schema")
    func testStringifyObjectSchema() {
        let schema = JSONSchema.object(
            title: "Test",
            properties: ["name": JSONSchema.string()]
        )

        let json = SchemaJSON.stringify(schema)

        #expect(json.contains("\"type\" : \"object\""))
        #expect(json.contains("\"title\" : \"Test\""))
    }

    @Test("Stringify nil schema returns empty string")
    func testStringifyNilSchema() {
        let json = SchemaJSON.stringify(nil)
        #expect(json.isEmpty)
    }

    @Test("Round trip conversion preserves schema")
    func testRoundTrip() {
        let original = JSONSchema.object(
            title: "Test",
            description: "Description",
            properties: [
                "name": JSONSchema.string(),
                "count": JSONSchema.integer()
            ],
            required: ["name"]
        )

        let json = SchemaJSON.stringify(original)
        let result = SchemaJSON.parse(json)

        switch result {
        case .success(let parsed):
            #expect(parsed.title == original.title)
            #expect(parsed.type == original.type)
        case .failure(let error):
            Issue.record("Round trip failed: \(error)")
        }
    }
}
