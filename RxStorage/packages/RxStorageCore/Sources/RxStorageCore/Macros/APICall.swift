//
//  APICall.swift
//  RxStorageCore
//
//  Macro declaration for handling API calls with automatic response handling
//

/// Success case types for API responses
public enum SuccessCase {
    case ok
    case created
    case noContent
}

/// Attached macro that wraps an API call with full response handling.
/// Generates switch statement for success/error cases and catches DecodingErrors.
///
/// ## Basic Usage
///
/// ```swift
/// @APICall(.ok)
/// public func fetchItem(id: Int) async throws -> StorageItemDetail {
///     try await StorageAPIClient.shared.client.getItem(.init(path: .init(id: String(id))))
/// }
///
/// @APICall(.created)
/// public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
///     try await StorageAPIClient.shared.client.createItem(.init(body: .json(request)))
/// }
///
/// @APICall(.noContent)
/// public func deleteItem(id: Int) async throws {
///     try await StorageAPIClient.shared.client.deleteItem(.init(path: .init(id: String(id))))
/// }
/// ```
///
/// ## With Transform
///
/// For responses that need custom transformation (e.g., pagination):
///
/// ```swift
/// @APICall(.ok, transform: "transformPaginated")
/// public func fetchItemsPaginated(filters: ItemFilters?) async throws -> PaginatedResponse<StorageItem> {
///     try await client.getItems(.init(query: query))
/// }
///
/// private func transformPaginated(_ body: Components.Schemas.PaginatedItemsResponse) -> PaginatedResponse<StorageItem> {
///     let pagination = PaginationState(from: body.pagination)
///     return PaginatedResponse(data: body.data, pagination: pagination)
/// }
/// ```
///
/// - Parameter successCase: The success case type (.ok, .created, or .noContent)
/// - Parameter transform: Optional name of a transform function to apply to the response body
/// - Note: Requires a `logger` variable to be in scope
@attached(body)
public macro APICall(_ successCase: SuccessCase) = #externalMacro(module: "RxStorageCoreMacros", type: "APICallMacro")

@attached(body)
public macro APICall(_ successCase: SuccessCase, transform: String) = #externalMacro(module: "RxStorageCoreMacros", type: "APICallMacro")
