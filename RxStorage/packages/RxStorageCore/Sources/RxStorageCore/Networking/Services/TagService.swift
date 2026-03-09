//
//  TagService.swift
//  RxStorageCore
//
//  Tag service protocol and implementation using generated client
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "TagService")

// MARK: - Protocol

/// Protocol for tag service operations
public protocol TagServiceProtocol: Sendable {
    func fetchTags(filters: TagFilters?) async throws -> [Tag]
    func fetchTagsPaginated(filters: TagFilters?) async throws -> PaginatedResponse<Tag>
    func fetchTag(id: String) async throws -> Tag
    func fetchTagDetail(id: String) async throws -> TagDetail
    func createTag(_ request: NewTagRequest) async throws -> Tag
    func updateTag(id: String, _ request: UpdateTagRequest) async throws -> Tag
    func deleteTag(id: String) async throws
    func fetchItemTags(itemId: String) async throws -> [TagRef]
    func addTagToItem(itemId: String, tagId: String) async throws
    func removeTagFromItem(itemId: String, tagId: String) async throws
}

// MARK: - Implementation

/// Tag service implementation using generated OpenAPI client
public struct TagService: TagServiceProtocol {
    public init() {}

    public func fetchTags(filters: TagFilters?) async throws -> [Tag] {
        let response = try await fetchTagsPaginated(filters: filters)
        return response.data
    }

    @APICall(.ok, transform: "transformPaginatedTags")
    public func fetchTagsPaginated(filters: TagFilters?) async throws -> PaginatedResponse<Tag> {
        let direction = filters?.direction.flatMap { Operations.getTags.Input.Query.directionPayload(rawValue: $0.rawValue) }
        let query = Operations.getTags.Input.Query(
            cursor: filters?.cursor,
            direction: direction,
            limit: filters?.limit,
            search: filters?.search
        )

        try await StorageAPIClient.shared.client.getTags(.init(query: query))
    }

    private func transformPaginatedTags(_ body: Components.Schemas.PaginatedTagsResponse) -> PaginatedResponse<Tag> {
        let pagination = PaginationState(from: body.pagination)
        return PaginatedResponse(data: body.data, pagination: pagination)
    }

    @APICall(.ok, transform: "transformTagFromDetail")
    public func fetchTag(id: String) async throws -> Tag {
        try await StorageAPIClient.shared.client.getTag(.init(path: .init(id: id)))
    }

    @APICall(.ok)
    public func fetchTagDetail(id: String) async throws -> TagDetail {
        try await StorageAPIClient.shared.client.getTag(.init(path: .init(id: id)))
    }

    /// Extracts base Tag from TagDetailResponseSchema
    private func transformTagFromDetail(_ body: TagDetail) -> Tag {
        Tag(id: body.id, userId: body.userId, title: body.title, color: body.color, createdAt: body.createdAt, updatedAt: body.updatedAt)
    }

    @APICall(.created)
    public func createTag(_ request: NewTagRequest) async throws -> Tag {
        try await StorageAPIClient.shared.client.createTag(.init(body: .json(request)))
    }

    @APICall(.ok)
    public func updateTag(id: String, _ request: UpdateTagRequest) async throws -> Tag {
        try await StorageAPIClient.shared.client.updateTag(.init(path: .init(id: id), body: .json(request)))
    }

    public func deleteTag(id: String) async throws {
        let response = try await StorageAPIClient.shared.client.deleteTag(.init(path: .init(id: id)))

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func fetchItemTags(itemId: String) async throws -> [TagRef] {
        let response = try await StorageAPIClient.shared.client.getItemTags(.init(path: .init(id: itemId)))

        switch response {
        case let .ok(okResponse):
            return try okResponse.body.json
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func addTagToItem(itemId: String, tagId: String) async throws {
        let request = Components.Schemas.ItemTagInsertSchema(tagId: tagId)
        let response = try await StorageAPIClient.shared.client.addItemTag(.init(path: .init(id: itemId), body: .json(request)))

        switch response {
        case .created:
            return
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }

    public func removeTagFromItem(itemId: String, tagId: String) async throws {
        let response = try await StorageAPIClient.shared.client.removeItemTag(.init(path: .init(id: itemId, tagId: tagId)))

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
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
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
