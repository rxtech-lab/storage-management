//
//  APICallMacro.swift
//  RxStorageCoreMacros
//
//  Swift macro for handling API calls with automatic response handling
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Attached body macro that wraps an API call with full response handling.
/// Generates switch statement for success/error cases and catches DecodingErrors.
public struct APICallMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in _: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let body = declaration.body else {
            throw MacroExpansionError.missingBody
        }

        let successCase = extractSuccessCase(from: node) ?? "ok"
        let transformFn = extractTransform(from: node)

        // Split statements: setup code vs API call (last statement)
        let allStatements = Array(body.statements)
        guard !allStatements.isEmpty else {
            throw MacroExpansionError.missingBody
        }

        let setupStatements = allStatements.dropLast()
        let apiCallStatement = allStatements.last!

        // Build the setup code block
        var setupCode = ""
        for stmt in setupStatements {
            setupCode += "\(stmt)"
        }

        // Generate return expression based on whether transform is provided
        let returnExpr: String
        if let transform = transformFn {
            returnExpr = "\(transform)(try okResponse.body.json)"
        } else {
            returnExpr = "try okResponse.body.json"
        }

        let createdReturnExpr: String
        if let transform = transformFn {
            createdReturnExpr = "\(transform)(try createdResponse.body.json)"
        } else {
            createdReturnExpr = "try createdResponse.body.json"
        }

        // Generate the wrapped code based on success case
        let wrappedCode: CodeBlockItemListSyntax

        if successCase == "noContent" {
            wrappedCode = """
            do {
                \(raw: setupCode)let response = \(apiCallStatement)
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
            """
        } else if successCase == "created" {
            wrappedCode = """
            do {
                \(raw: setupCode)let response = \(apiCallStatement)
                switch response {
                case .created(let createdResponse):
                    return \(raw: createdReturnExpr)
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
            """
        } else {
            // Default to .ok
            wrappedCode = """
            do {
                \(raw: setupCode)let response = \(apiCallStatement)
                switch response {
                case .ok(let okResponse):
                    return \(raw: returnExpr)
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
            """
        }

        return Array(wrappedCode)
    }

    private static func extractSuccessCase(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments,
              case let .argumentList(argList) = arguments,
              let firstArg = argList.first?.expression
        else {
            return nil
        }

        if let memberAccess = firstArg.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName.text
        }

        return nil
    }

    private static func extractTransform(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments,
              case let .argumentList(argList) = arguments
        else {
            return nil
        }

        // Find the transform argument
        for arg in argList {
            if arg.label?.text == "transform",
               let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                return segment.content.text
            }
        }

        return nil
    }
}

/// Errors that can occur during macro expansion
enum MacroExpansionError: Error, CustomStringConvertible {
    case missingBody

    var description: String {
        switch self {
        case .missingBody:
            return "@APICall can only be applied to functions with a body"
        }
    }
}

@main
struct RxStorageCoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        APICallMacro.self,
    ]
}
