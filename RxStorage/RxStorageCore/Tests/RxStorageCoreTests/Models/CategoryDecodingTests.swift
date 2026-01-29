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

        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        let category = try decoder.decode(Category.self, from: data)
        #expect(category.id == 2)
        #expect(category.userId == "b0b8b768-c625-4c82-99ae-b6c93be21dce")
        #expect(category.name == "Test")
        #expect(category.description == nil)
        #expect(category.createdAt != nil)
        #expect(category.updatedAt != nil)
    }

    @Test("Decode category with minimal fields")
    func decodeCategoryMinimalFields() throws {
        let json = """
            {"id":5,"name":"Minimal"}
            """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let category = try decoder.decode(Category.self, from: data)
        #expect(category.id == 5)
        #expect(category.name == "Minimal")
        #expect(category.userId == nil)
        #expect(category.description == nil)
        #expect(category.createdAt == nil)
        #expect(category.updatedAt == nil)
    }
}
