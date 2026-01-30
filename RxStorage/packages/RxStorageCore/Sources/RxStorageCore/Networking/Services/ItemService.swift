//
//  ItemService.swift
//  RxStorageCore
//
//  API service for storage item operations
//

import Foundation

/// Protocol for item service operations
@MainActor
public protocol ItemServiceProtocol {
    func fetchItems(filters: ItemFilters?) async throws -> [StorageItem]
    func fetchItem(id: Int) async throws -> StorageItem
    func fetchChildren(parentId: Int) async throws -> [StorageItem]
    func createItem(_ request: NewItemRequest) async throws -> StorageItem
    func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem
    func setItemParent(childId: String, parentId: Int?) async throws -> StorageItem
    func deleteItem(id: Int) async throws
    func generateQRCode(itemId: Int) async throws -> QRCodeData
}

/// Item service implementation
@MainActor
public class ItemService: ItemServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func fetchItems(filters: ItemFilters? = nil) async throws -> [StorageItem] {
        return try await apiClient.get(
            .listItems(filters: filters),
            responseType: [StorageItem].self
        )
    }

    public func fetchItem(id: Int) async throws -> StorageItem {
        return try await apiClient.get(
            .getItem(id: id),
            responseType: StorageItem.self
        )
    }

    public func fetchChildren(parentId: Int) async throws -> [StorageItem] {
        return try await apiClient.get(
            .getItemChildren(id: parentId),
            responseType: [StorageItem].self
        )
    }

    public func createItem(_ request: NewItemRequest) async throws -> StorageItem {
        return try await apiClient.post(
            .createItem,
            body: request,
            responseType: StorageItem.self
        )
    }

    public func updateItem(id: Int, _ request: UpdateItemRequest) async throws -> StorageItem {
        return try await apiClient.put(
            .updateItem(id: id),
            body: request,
            responseType: StorageItem.self
        )
    }

    public func setItemParent(childId: String, parentId: Int?) async throws -> StorageItem {
        struct SetParentRequest: Encodable, Sendable {
            let parentId: Int?
        }
        return try await apiClient.put(
            .setItemParent(id: childId),
            body: SetParentRequest(parentId: parentId),
            responseType: StorageItem.self
        )
    }

    public func deleteItem(id: Int) async throws {
        try await apiClient.delete(.deleteItem(id: id))
    }

    public func generateQRCode(itemId: Int) async throws -> QRCodeData {
        return try await apiClient.get(
            .getItemQR(id: itemId),
            responseType: QRCodeData.self
        )
    }
}
