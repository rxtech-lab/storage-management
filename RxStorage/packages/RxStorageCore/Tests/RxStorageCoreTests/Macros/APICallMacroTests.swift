//
//  APICallMacroTests.swift
//  RxStorageCoreTests
//
//  Tests for the APICall macro expansion
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import RxStorageCoreMacros

@Suite("APICall Macro Expansion Tests")
struct APICallMacroTests {

    @Test("APICall(.ok) macro wraps single API call")
    func testOkMacroExpansion() {
        assertMacroExpansion(
            """
            @APICall(.ok)
            func fetchItem(id: Int) async throws -> Item {
                try await client.getItem(.init(path: .init(id: String(id))))
            }
            """,
            expandedSource: """
            func fetchItem(id: Int) async throws -> Item {
                do {
                    let response = try await client.getItem(.init(path: .init(id: String(id))))
                    switch response {
                    case .ok(let okResponse):
                        return try okResponse.body.json
                    case .badRequest(let badRequest):
                        let error = try? badRequest.body.json
                        throw APIError.badRequest(error?.error ?? "Invalid request")
                    case .unauthorized:
                        throw APIError.unauthorized
                    case .forbidden:
                        throw APIError.forbidden
                    case .notFound:
                        throw APIError.notFound
                    case .internalServerError:
                        throw APIError.serverError("Internal server error")
                    case .undocumented(let statusCode, _):
                        throw APIError.serverError("HTTP \\(statusCode)")
                    }
                } catch let clientError as ClientError {
                    if let decodingError = clientError.underlyingError as? DecodingError {
                        logger.error("Decoding error: \\(describeDecodingError(decodingError))")
                    } else {
                        logger.error("Client error: \\(clientError)")
                    }
                    throw APIError.serverError("Unable to decode response data")
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                } catch {
                    logger.error("Unexpected error: \\(error)")
                    throw error
                }
            }
            """,
            macros: ["APICall": APICallMacro.self]
        )
    }

    @Test("APICall(.created) macro handles created response")
    func testCreatedMacroExpansion() {
        assertMacroExpansion(
            """
            @APICall(.created)
            func createItem(_ request: NewItemRequest) async throws -> Item {
                try await client.createItem(.init(body: .json(request)))
            }
            """,
            expandedSource: """
            func createItem(_ request: NewItemRequest) async throws -> Item {
                do {
                    let response = try await client.createItem(.init(body: .json(request)))
                    switch response {
                    case .created(let createdResponse):
                        return try createdResponse.body.json
                    case .badRequest(let badRequest):
                        let error = try? badRequest.body.json
                        throw APIError.badRequest(error?.error ?? "Invalid request")
                    case .unauthorized:
                        throw APIError.unauthorized
                    case .forbidden:
                        throw APIError.forbidden
                    case .notFound:
                        throw APIError.notFound
                    case .internalServerError:
                        throw APIError.serverError("Internal server error")
                    case .undocumented(let statusCode, _):
                        throw APIError.serverError("HTTP \\(statusCode)")
                    }
                } catch let clientError as ClientError {
                    if let decodingError = clientError.underlyingError as? DecodingError {
                        logger.error("Decoding error: \\(describeDecodingError(decodingError))")
                    } else {
                        logger.error("Client error: \\(clientError)")
                    }
                    throw APIError.serverError("Unable to decode response data")
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                } catch {
                    logger.error("Unexpected error: \\(error)")
                    throw error
                }
            }
            """,
            macros: ["APICall": APICallMacro.self]
        )
    }

    @Test("APICall(.noContent) macro handles void response")
    func testNoContentMacroExpansion() {
        assertMacroExpansion(
            """
            @APICall(.noContent)
            func deleteItem(id: Int) async throws {
                try await client.deleteItem(.init(path: .init(id: String(id))))
            }
            """,
            expandedSource: """
            func deleteItem(id: Int) async throws {
                do {
                    let response = try await client.deleteItem(.init(path: .init(id: String(id))))
                    switch response {
                    case .noContent:
                        return
                    case .badRequest(let badRequest):
                        let error = try? badRequest.body.json
                        throw APIError.badRequest(error?.error ?? "Invalid request")
                    case .unauthorized:
                        throw APIError.unauthorized
                    case .forbidden:
                        throw APIError.forbidden
                    case .notFound:
                        throw APIError.notFound
                    case .internalServerError:
                        throw APIError.serverError("Internal server error")
                    case .undocumented(let statusCode, _):
                        throw APIError.serverError("HTTP \\(statusCode)")
                    }
                } catch let clientError as ClientError {
                    if let decodingError = clientError.underlyingError as? DecodingError {
                        logger.error("Decoding error: \\(describeDecodingError(decodingError))")
                    } else {
                        logger.error("Client error: \\(clientError)")
                    }
                    throw APIError.serverError("Unable to decode response data")
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                } catch {
                    logger.error("Unexpected error: \\(error)")
                    throw error
                }
            }
            """,
            macros: ["APICall": APICallMacro.self]
        )
    }

    @Test("APICall macro preserves setup code before API call")
    func testMacroWithSetupCode() {
        assertMacroExpansion(
            """
            @APICall(.ok)
            func setParent(itemId: Int, parentId: Int?) async throws -> Item {
                let request = SetParentRequest(parentId: parentId)
                try await client.setItemParent(.init(path: .init(id: String(itemId)), body: .json(request)))
            }
            """,
            expandedSource: """
            func setParent(itemId: Int, parentId: Int?) async throws -> Item {
                do {
                    let request = SetParentRequest(parentId: parentId)
                    let response = try await client.setItemParent(.init(path: .init(id: String(itemId)), body: .json(request)))
                    switch response {
                    case .ok(let okResponse):
                        return try okResponse.body.json
                    case .badRequest(let badRequest):
                        let error = try? badRequest.body.json
                        throw APIError.badRequest(error?.error ?? "Invalid request")
                    case .unauthorized:
                        throw APIError.unauthorized
                    case .forbidden:
                        throw APIError.forbidden
                    case .notFound:
                        throw APIError.notFound
                    case .internalServerError:
                        throw APIError.serverError("Internal server error")
                    case .undocumented(let statusCode, _):
                        throw APIError.serverError("HTTP \\(statusCode)")
                    }
                } catch let clientError as ClientError {
                    if let decodingError = clientError.underlyingError as? DecodingError {
                        logger.error("Decoding error: \\(describeDecodingError(decodingError))")
                    } else {
                        logger.error("Client error: \\(clientError)")
                    }
                    throw APIError.serverError("Unable to decode response data")
                } catch let error as DecodingError {
                    logger.error("Decoding error: \\(describeDecodingError(error))")
                    throw APIError.serverError("Unable to decode response data")
                } catch {
                    logger.error("Unexpected error: \\(error)")
                    throw error
                }
            }
            """,
            macros: ["APICall": APICallMacro.self]
        )
    }
}
