//
//  DecodingErrorDescriberTests.swift
//  RxStorageCoreTests
//
//  Tests for the describeDecodingError utility function
//

import Foundation
@testable import RxStorageCore
import Testing

/// Helper CodingKey for constructing test coding paths
struct TestCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        stringValue = string
        intValue = nil
    }

    init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }
}

@Suite("DecodingErrorDescriber Tests")
struct DecodingErrorDescriberTests {
    // MARK: - Type Mismatch Tests

    @Test("Describes typeMismatch with coding path")
    func typeMismatchWithPath() {
        let error = DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: [TestCodingKey("items"), TestCodingKey(intValue: 0), TestCodingKey("id")],
                debugDescription: "Expected Int but found String"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Type mismatch"))
        #expect(description.contains("Int"))
        #expect(description.contains("items.0.id"))
        #expect(description.contains("Expected Int but found String"))
    }

    @Test("Describes typeMismatch at root level")
    func typeMismatchAtRoot() {
        let error = DecodingError.typeMismatch(
            [Int].self,
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Expected array but found object"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Type mismatch"))
        #expect(description.contains("root"))
        #expect(description.contains("Expected array but found object"))
    }

    // MARK: - Value Not Found Tests

    @Test("Describes valueNotFound with coding path")
    func valueNotFoundWithPath() {
        let error = DecodingError.valueNotFound(
            String.self,
            DecodingError.Context(
                codingPath: [TestCodingKey("user"), TestCodingKey("name")],
                debugDescription: "Expected String value but found null instead"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Value not found"))
        #expect(description.contains("String"))
        #expect(description.contains("user.name"))
        #expect(description.contains("Expected String value but found null instead"))
    }

    @Test("Describes valueNotFound at root level")
    func valueNotFoundAtRoot() {
        let error = DecodingError.valueNotFound(
            Int.self,
            DecodingError.Context(
                codingPath: [],
                debugDescription: "No value present"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Value not found"))
        #expect(description.contains("root"))
    }

    // MARK: - Key Not Found Tests

    @Test("Describes keyNotFound with coding path")
    func keyNotFoundWithPath() {
        let error = DecodingError.keyNotFound(
            TestCodingKey("title"),
            DecodingError.Context(
                codingPath: [TestCodingKey("items"), TestCodingKey(intValue: 0)],
                debugDescription: "No value associated with key 'title'"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Key not found"))
        #expect(description.contains("'title'"))
        #expect(description.contains("items.0"))
        #expect(description.contains("No value associated with key 'title'"))
    }

    @Test("Describes keyNotFound at root level")
    func keyNotFoundAtRoot() {
        let error = DecodingError.keyNotFound(
            TestCodingKey("id"),
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Missing required key 'id'"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Key not found"))
        #expect(description.contains("'id'"))
        #expect(description.contains("root"))
    }

    // MARK: - Data Corrupted Tests

    @Test("Describes dataCorrupted with coding path")
    func dataCorruptedWithPath() {
        let error = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [TestCodingKey("response"), TestCodingKey("data")],
                debugDescription: "Invalid JSON structure"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Data corrupted"))
        #expect(description.contains("response.data"))
        #expect(description.contains("Invalid JSON structure"))
    }

    @Test("Describes dataCorrupted at root level")
    func dataCorruptedAtRoot() {
        let error = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "The given data was not valid JSON"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("Data corrupted"))
        #expect(description.contains("root"))
        #expect(description.contains("The given data was not valid JSON"))
    }

    // MARK: - Coding Path Format Tests

    @Test("Formats deeply nested coding path correctly")
    func deeplyNestedPath() {
        let error = DecodingError.typeMismatch(
            Bool.self,
            DecodingError.Context(
                codingPath: [
                    TestCodingKey("response"),
                    TestCodingKey("data"),
                    TestCodingKey("items"),
                    TestCodingKey(intValue: 2),
                    TestCodingKey("metadata"),
                    TestCodingKey("isActive"),
                ],
                debugDescription: "Expected Bool"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("response.data.items.2.metadata.isActive"))
    }

    @Test("Handles integer index keys in path")
    func integerIndexKeys() {
        let error = DecodingError.valueNotFound(
            String.self,
            DecodingError.Context(
                codingPath: [
                    TestCodingKey("array"),
                    TestCodingKey(intValue: 0),
                    TestCodingKey(intValue: 1),
                    TestCodingKey("value"),
                ],
                debugDescription: "Missing value"
            )
        )

        let description = describeDecodingError(error)

        #expect(description.contains("array.0.1.value"))
    }
}
