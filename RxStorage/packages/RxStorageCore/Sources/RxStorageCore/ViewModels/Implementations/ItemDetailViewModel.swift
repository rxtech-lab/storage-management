//
//  ItemDetailViewModel.swift
//  RxStorageCore
//
//  Item detail view model implementation
//

import Foundation
import Observation

/// Item detail view model implementation
@Observable
@MainActor
public final class ItemDetailViewModel: ItemDetailViewModelProtocol {
    // MARK: - Published Properties

    public private(set) var item: StorageItem?
    public private(set) var children: [StorageItem] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Dependencies

    private let itemService: ItemServiceProtocol

    // MARK: - Initialization

    public init(itemService: ItemServiceProtocol = ItemService()) {
        self.itemService = itemService
    }

    // MARK: - Public Methods

    public func fetchItem(id: Int) async {
        isLoading = true
        error = nil

        do {
            item = try await itemService.fetchItem(id: id)
            isLoading = false

            // Fetch children if item exists
            if item != nil {
                await fetchChildren()
            }
        } catch {
            self.error = error
            isLoading = false
        }
    }

    public func fetchChildren() async {
        guard let itemId = item?.id else { return }

        do {
            children = try await itemService.fetchChildren(parentId: itemId)
        } catch {
            // Don't set main error for children fetch failure
            print("Failed to fetch children: \(error)")
        }
    }

    public func refresh() async {
        guard let itemId = item?.id else { return }
        await fetchItem(id: itemId)
    }
}
