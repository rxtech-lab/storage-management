//
//  APIClientDecodingTests.swift
//  RxStorageCoreTests
//
//  Tests for APIClient response decoding logic
//

import Foundation
import Logging
import Testing

@testable import RxStorageCore

/// Type alias to avoid ambiguity with Objective-C Category type
private typealias CategoryModel = RxStorageCore.Category

/// Helper to access internal decodeResponse method
enum APIClientTestHelper {
    private static let logger = Logger(label: "com.rxlab.rxstorage.test")

    static func decodeResponse<T: Codable & Sendable>(data: Data, responseType: T.Type) throws -> T {
        try APIClient.decodeResponse(data: data, responseType: responseType, logger: logger)
    }
}

@Suite("APIClient Response Decoding")
struct APIClientDecodingTests {

    @Test("Direct model JSON decodes successfully")
    func directModelDecoding() throws {
        let json = """
            {"id":2,"userId":"user-123","name":"Test","description":null,"createdAt":"2026-01-29T05:34:44.000Z","updatedAt":"2026-01-29T05:34:44.000Z"}
            """
        let data = json.data(using: .utf8)!

        let category: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        #expect(category.id == 2)
        #expect(category.userId == "user-123")
        #expect(category.name == "Test")
        #expect(category.description == nil)
        #expect(category.createdAt != nil)
        #expect(category.updatedAt != nil)
    }

    @Test("APIResponse-wrapped model decodes successfully")
    func wrappedModelDecoding() throws {
        let json = """
            {"data":{"id":3,"name":"Wrapped"}}
            """
        let data = json.data(using: .utf8)!

        let category: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        #expect(category.id == 3)
        #expect(category.name == "Wrapped")
    }

    @Test("APIResponse with error throws serverError")
    func errorResponseThrows() throws {
        let json = """
            {"error":"Something went wrong"}
            """
        let data = json.data(using: .utf8)!

        #expect(throws: APIError.self) {
            let _: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        }
    }

    @Test("Array response decodes successfully")
    func arrayResponseDecoding() throws {
        let json = """
            [{"id":1,"name":"First"},{"id":2,"name":"Second","description":"desc"}]
            """
        let data = json.data(using: .utf8)!

        let categories: [CategoryModel] = try APIClientTestHelper.decodeResponse(
            data: data, responseType: [CategoryModel].self)
        #expect(categories.count == 2)
        #expect(categories[0].id == 1)
        #expect(categories[0].name == "First")
        #expect(categories[1].id == 2)
        #expect(categories[1].name == "Second")
        #expect(categories[1].description == "desc")
    }

    @Test("Model with all fields decodes successfully")
    func fullModelDecoding() throws {
        let json = """
            {"id":5,"userId":"full-user","name":"Full Category","description":"A category with all fields","createdAt":"2026-01-15T10:30:00Z","updatedAt":"2026-01-20T14:45:00Z"}
            """
        let data = json.data(using: .utf8)!

        let category: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        #expect(category.id == 5)
        #expect(category.userId == "full-user")
        #expect(category.name == "Full Category")
        #expect(category.description == "A category with all fields")
        #expect(category.createdAt != nil)
        #expect(category.updatedAt != nil)
    }

    @Test("Minimal model decodes successfully")
    func minimalModelDecoding() throws {
        let json = """
            {"id":10,"name":"Minimal"}
            """
        let data = json.data(using: .utf8)!

        let category: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        #expect(category.id == 10)
        #expect(category.name == "Minimal")
        #expect(category.userId == nil)
        #expect(category.description == nil)
        #expect(category.createdAt == nil)
        #expect(category.updatedAt == nil)
    }

    @Test("Invalid JSON throws decodingError")
    func invalidJsonThrows() throws {
        let json = """
            {"invalid": json content}
            """
        let data = json.data(using: .utf8)!

        #expect(throws: APIError.self) {
            let _: CategoryModel = try APIClientTestHelper.decodeResponse(data: data, responseType: CategoryModel.self)
        }
    }

    @Test("Wrapped array response decodes successfully")
    func wrappedArrayDecoding() throws {
        let json = """
            {"data":[{"id":1,"name":"First"},{"id":2,"name":"Second"}]}
            """
        let data = json.data(using: .utf8)!

        let categories: [CategoryModel] = try APIClientTestHelper.decodeResponse(
            data: data, responseType: [CategoryModel].self)
        #expect(categories.count == 2)
    }
}
