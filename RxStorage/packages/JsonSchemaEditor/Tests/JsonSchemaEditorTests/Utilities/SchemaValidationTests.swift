//
//  SchemaValidationTests.swift
//  JsonSchemaEditorTests
//

import JSONSchema
@testable import JsonSchemaEditor
import Testing

@Suite("Schema Validation Tests")
struct SchemaValidationTests {
    @Test("Valid property key passes validation")
    func validPropertyKey() {
        let result = SchemaValidation.validatePropertyKey("validKey")
        #expect(result.isValid == true)
        #expect(result.error == nil)
    }

    @Test("Property key with underscore prefix is valid")
    func propertyKeyWithUnderscorePrefix() {
        let result = SchemaValidation.validatePropertyKey("_privateKey")
        #expect(result.isValid == true)
    }

    @Test("Property key with numbers is valid")
    func propertyKeyWithNumbers() {
        let result = SchemaValidation.validatePropertyKey("key123")
        #expect(result.isValid == true)
    }

    @Test("Property key must start with letter or underscore")
    func propertyKeyMustStartWithLetterOrUnderscore() {
        let result = SchemaValidation.validatePropertyKey("123invalid")
        #expect(result.isValid == false)
        #expect(result.error != nil)
    }

    @Test("Empty property key fails validation")
    func emptyPropertyKey() {
        let result = SchemaValidation.validatePropertyKey("")
        #expect(result.isValid == false)
        #expect(result.error?.contains("required") == true)
    }

    @Test("Property key with special characters fails")
    func propertyKeyWithSpecialCharacters() {
        let result = SchemaValidation.validatePropertyKey("invalid-key")
        #expect(result.isValid == false)
    }

    @Test("Property key with spaces fails")
    func propertyKeyWithSpaces() {
        let result = SchemaValidation.validatePropertyKey("invalid key")
        #expect(result.isValid == false)
    }

    @Test("Unique key check returns true for unique key")
    func uniqueKeyCheckTrue() {
        let existing = ["name", "age", "email"]
        let isUnique = SchemaValidation.isKeyUnique("phone", existingKeys: existing, excluding: nil)
        #expect(isUnique == true)
    }

    @Test("Unique key check returns false for duplicate key")
    func uniqueKeyCheckFalse() {
        let existing = ["name", "age", "email"]
        let isUnique = SchemaValidation.isKeyUnique("name", existingKeys: existing, excluding: nil)
        #expect(isUnique == false)
    }

    @Test("Unique key check with exclusion")
    func uniqueKeyCheckWithExclusion() {
        let existing = ["name", "age", "email"]
        let isUnique = SchemaValidation.isKeyUnique("name", existingKeys: existing, excluding: "name")
        #expect(isUnique == true)
    }

    @Test("Validate object schema with valid keys")
    func validateObjectSchemaWithValidKeys() {
        let schema = JSONSchema.object(
            properties: [
                "validKey": JSONSchema.string(),
                "anotherValid": JSONSchema.integer(),
            ]
        )
        let result = SchemaValidation.validateSchema(schema)
        #expect(result.isValid == true)
    }

    @Test("Validate object schema with invalid key")
    func validateObjectSchemaWithInvalidKey() {
        let schema = JSONSchema.object(
            properties: [
                "valid": JSONSchema.string(),
                "123invalid": JSONSchema.integer(),
            ]
        )
        let result = SchemaValidation.validateSchema(schema)
        #expect(result.isValid == false)
    }
}
