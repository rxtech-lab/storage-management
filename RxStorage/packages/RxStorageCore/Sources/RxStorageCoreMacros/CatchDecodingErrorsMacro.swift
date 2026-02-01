//
//  CatchDecodingErrorsMacro.swift
//  RxStorageCoreMacros
//
//  Swift macro for catching and logging DecodingErrors in service functions
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Freestanding expression macro that wraps an async throwing expression to catch DecodingErrors,
/// log them with detailed context, and rethrow. Other errors pass through unchanged.
public struct CatchDecodingErrorsMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Get the logger argument
        guard let loggerArg = node.arguments.first?.expression else {
            throw MacroExpansionError.missingLogger
        }

        // Get the closure (either trailing or as second argument)
        guard let closureArg = node.trailingClosure else {
            throw MacroExpansionError.missingClosure
        }

        // Generate the do-catch block
        return """
            {
                do {
                    return try await \(closureArg)()
                } catch let error as DecodingError {
                    \(loggerArg).error("Decoding error: \\(describeDecodingError(error))")
                    throw error
                }
            }()
            """
    }
}

/// Attached body macro that wraps a function body to catch DecodingErrors,
/// log them with detailed context, and rethrow as APIError.
public struct CatchDecodingErrorsBodyMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        // Get the original function body
        guard let body = declaration.body else {
            throw MacroExpansionError.missingBody
        }

        // Extract the statements from the body
        let statements = body.statements

        // Wrap in do-catch that handles DecodingError
        let wrappedCode: CodeBlockItemListSyntax = """
            do {
                \(statements)
            } catch let error as DecodingError {
                logger.error("Decoding error: \\(describeDecodingError(error))")
                throw APIError.serverError("Unable to decode response data")
            }
            """

        return Array(wrappedCode)
    }
}

/// Errors that can occur during macro expansion
enum MacroExpansionError: Error, CustomStringConvertible {
    case missingLogger
    case missingClosure
    case missingBody

    var description: String {
        switch self {
        case .missingLogger:
            return "#catchDecodingErrors requires a Logger as the first argument"
        case .missingClosure:
            return "#catchDecodingErrors requires a trailing closure containing the throwing expression"
        case .missingBody:
            return "@CatchDecodingErrors can only be applied to functions with a body"
        }
    }
}

@main
struct RxStorageCoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CatchDecodingErrorsMacro.self,
        CatchDecodingErrorsBodyMacro.self,
    ]
}
