//
//  CatchDecodingErrorsMacroTests.swift
//  RxStorageCoreTests
//
//  Tests for the CatchDecodingErrors macro expansion
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import RxStorageCoreMacros

@Suite("CatchDecodingErrors Macro Expansion Tests")
struct CatchDecodingErrorsMacroTests {

    // MARK: - Freestanding Macro Tests

    @Test("Freestanding macro expands to do-catch block with logger")
    func testFreestandingMacroExpansion() {
        assertMacroExpansion(
            """
            #catchDecodingErrors(logger) {
                try await fetchData()
            }
            """,
            expandedSource: """
            {
                do {
                    return try await {
                        try await fetchData()
                    }()
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw error
                }
            }()
            """,
            macros: ["catchDecodingErrors": CatchDecodingErrorsMacro.self]
        )
    }

    @Test("Freestanding macro preserves complex expressions in closure")
    func testFreestandingMacroWithComplexExpression() {
        assertMacroExpansion(
            """
            #catchDecodingErrors(serviceLogger) {
                try await client.getItem(path: .init(id: itemId))
            }
            """,
            expandedSource: """
            {
                do {
                    return try await {
                        try await client.getItem(path: .init(id: itemId))
                    }()
                } catch let error as DecodingError {
                    serviceLogger.error("Decoding error: \\(describeDecodingError(error))")
                    throw error
                }
            }()
            """,
            macros: ["catchDecodingErrors": CatchDecodingErrorsMacro.self]
        )
    }

    @Test("Freestanding macro handles multiline closure body")
    func testFreestandingMacroWithMultilineBody() {
        assertMacroExpansion(
            """
            #catchDecodingErrors(logger) {
                let response = try await client.fetch()
                return try response.body.json
            }
            """,
            expandedSource: """
            {
                do {
                    return try await {
                        let response = try await client.fetch()
                        return try response.body.json
                    }()
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw error
                }
            }()
            """,
            macros: ["catchDecodingErrors": CatchDecodingErrorsMacro.self]
        )
    }

    // MARK: - Body Macro Tests

    @Test("Body macro wraps function body in do-catch")
    func testBodyMacroExpansion() {
        assertMacroExpansion(
            """
            @CatchDecodingErrors
            func fetchItem() async throws -> Item {
                let response = try await client.getItem()
                return try response.body.json
            }
            """,
            expandedSource: """
            func fetchItem() async throws -> Item {
                do {
                    let response = try await client.getItem()
                    return try response.body.json
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                }
            }
            """,
            macros: ["CatchDecodingErrors": CatchDecodingErrorsBodyMacro.self]
        )
    }

    @Test("Body macro works with public async throwing function")
    func testBodyMacroWithPublicFunction() {
        assertMacroExpansion(
            """
            @CatchDecodingErrors
            public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
                let client = StorageAPIClient.shared.optionalAuthClient
                let response = try await client.getItem(.init(path: .init(id: String(id))))
                switch response {
                case .ok(let okResponse):
                    return try okResponse.body.json
                default:
                    throw APIError.serverError("Unexpected response")
                }
            }
            """,
            expandedSource: """
            public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
                do {
                    let client = StorageAPIClient.shared.optionalAuthClient
                    let response = try await client.getItem(.init(path: .init(id: String(id))))
                    switch response {
                    case .ok(let okResponse):
                        return try okResponse.body.json
                    default:
                        throw APIError.serverError("Unexpected response")
                    }
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                }
            }
            """,
            macros: ["CatchDecodingErrors": CatchDecodingErrorsBodyMacro.self]
        )
    }

    @Test("Body macro transforms DecodingError to APIError.serverError")
    func testBodyMacroErrorTransformation() {
        // This test verifies the macro generates code that transforms
        // DecodingError into APIError.serverError with a user-friendly message
        assertMacroExpansion(
            """
            @CatchDecodingErrors
            func decode() async throws -> Data {
                try decoder.decode(Data.self, from: json)
            }
            """,
            expandedSource: """
            func decode() async throws -> Data {
                do {
                    try decoder.decode(Data.self, from: json)
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                }
            }
            """,
            macros: ["CatchDecodingErrors": CatchDecodingErrorsBodyMacro.self]
        )
    }
}
