//
//  CatchDecodingErrors.swift
//  RxStorageCore
//
//  Macro declaration for catching and logging DecodingErrors
//

import Logging

/// Wraps an async throwing expression to catch and log DecodingErrors with detailed context.
/// Other errors are rethrown unchanged.
///
/// This macro is useful in service functions where you want to log detailed decoding error
/// information for debugging while still propagating the error to callers.
///
/// ## Usage
///
/// ```swift
/// let logger = Logger(label: "ItemService")
///
/// public func fetchItem(id: Int) async throws -> StorageItemDetail {
///     let response = try await #catchDecodingErrors(logger) {
///         try await client.getItem(path: .init(id: id))
///     }
///     // handle response...
/// }
/// ```
///
/// ## Generated Code
///
/// The macro expands to:
/// ```swift
/// {
///     do {
///         return try await { /* your closure */ }()
///     } catch let error as DecodingError {
///         logger.error("Decoding error: \(describeDecodingError(error))")
///         throw error
///     }
/// }()
/// ```
///
/// - Parameters:
///   - logger: A `Logger` instance to use for error logging
///   - body: An async throwing closure containing the operation to wrap
/// - Returns: The result of the closure if successful
/// - Throws: The original error after logging (for DecodingError) or unchanged (for other errors)
@freestanding(expression)
public macro catchDecodingErrors<T>(
    _ logger: Logger,
    _ body: () async throws -> T
) -> T = #externalMacro(module: "RxStorageCoreMacros", type: "CatchDecodingErrorsMacro")

/// Attached macro that wraps a function body to catch and log DecodingErrors with detailed context,
/// then rethrows as APIError.serverError for user-friendly error handling.
///
/// ## Usage
///
/// ```swift
/// @CatchDecodingErrors
/// public func fetchPreviewItem(id: Int) async throws -> StorageItemDetail {
///     let client = StorageAPIClient.shared.optionalAuthClient
///     let response = try await client.getItem(.init(path: .init(id: String(id))))
///
///     switch response {
///     case .ok(let okResponse):
///         return try okResponse.body.json
///     // ... handle other cases
///     }
/// }
/// ```
///
/// ## Generated Code
///
/// The macro wraps the function body in:
/// ```swift
/// do {
///     // original function body
/// } catch let error as DecodingError {
///     logger.error("Decoding error: \(describeDecodingError(error))")
///     throw APIError.serverError("Unable to decode response data")
/// }
/// ```
///
/// - Note: Requires a `logger` variable to be in scope (module-level or passed in)
@attached(body)
public macro CatchDecodingErrors() = #externalMacro(module: "RxStorageCoreMacros", type: "CatchDecodingErrorsBodyMacro")
