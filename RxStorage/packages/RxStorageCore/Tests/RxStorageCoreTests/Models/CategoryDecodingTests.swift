//
//  CategoryDecodingTests.swift
//  RxStorageCoreTests
//

import Foundation
import Testing

@testable import RxStorageCore

@Suite("Category Decoding")
struct CategoryDecodingTests {

    @Test("Decode category with fractional seconds")
    func decodeCategoryWithFractionalSeconds() throws {
        let json = """
            {"id":2,"userId":"b0b8b768-c625-4c82-99ae-b6c93be21dce","name":"Test","description":null,"createdAt":"2026-01-29T05:34:44.000Z","updatedAt":"2026-01-29T05:34:44.000Z"}
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder.apiDecoder()

        let category = try decoder.decode(Category.self, from: data)
        #expect(category.id == 2)
        #expect(category.userId == "b0b8b768-c625-4c82-99ae-b6c93be21dce")
        #expect(category.name == "Test")
        #expect(category.description == nil)
        #expect(category.createdAt != nil)
        #expect(category.updatedAt != nil)
    }

    @Test("Decode category without fractional seconds")
    func decodeCategoryWithoutFractionalSeconds() throws {
        let json = """
            {"id":3,"userId":"user-123","name":"NoFractional","description":"test","createdAt":"2026-01-29T05:34:44Z","updatedAt":"2026-01-29T05:34:44Z"}
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder.apiDecoder()

        let category = try decoder.decode(Category.self, from: data)
        #expect(category.id == 3)
        #expect(category.userId == "user-123")
        #expect(category.name == "NoFractional")
        #expect(category.description == "test")
        #expect(category.createdAt != nil)
        #expect(category.updatedAt != nil)
    }

    @Test("Decode category with minimal fields")
    func decodeCategoryMinimalFields() throws {
        let json = """
            {"id":5,"name":"Minimal"}
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder.apiDecoder()

        let category = try decoder.decode(Category.self, from: data)
        #expect(category.id == 5)
        #expect(category.name == "Minimal")
        #expect(category.userId == nil)
        #expect(category.description == nil)
        #expect(category.createdAt == nil)
        #expect(category.updatedAt == nil)
    }

    @Test("Decode category array")
    func decodeCategoryArray() throws {
        let json = """
            [{"id":1,"name":"First"},{"id":2,"name":"Second","description":"desc"}]
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder.apiDecoder()

        let categories: [RxStorageCore.Category] = try decoder.decode(
            [RxStorageCore.Category].self, from: data)
        #expect(categories.count == 2)
        #expect(categories[0].id == 1)
        #expect(categories[0].name == "First")
        #expect(categories[1].id == 2)
        #expect(categories[1].name == "Second")
        #expect(categories[1].description == "desc")
    }
}
