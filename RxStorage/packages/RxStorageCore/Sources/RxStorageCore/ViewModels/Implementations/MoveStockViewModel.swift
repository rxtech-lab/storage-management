//
//  MoveStockViewModel.swift
//  RxStorageCore
//
//  Moves some or all units of an item from one placement to a destination parent
//

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.rxlab.rxstorage", category: "MoveStockViewModel")

/// A placement units can be moved from: the item's main placement or one of its stock placements
public struct StockSource: Identifiable, Hashable, Sendable {
    /// Stock placement ID, nil for the item's main placement
    public let stockId: String?
    public let parentId: String?
    public let parentTitle: String?
    public let locationTitle: String?
    public let quantity: Int

    public var id: String {
        stockId ?? "main"
    }

    public var isMain: Bool {
        stockId == nil
    }

    /// Human readable name of where these units are
    public var displayName: String {
        parentTitle ?? "No parent"
    }

    public init(
        stockId: String?,
        parentId: String?,
        parentTitle: String?,
        locationTitle: String?,
        quantity: Int
    ) {
        self.stockId = stockId
        self.parentId = parentId
        self.parentTitle = parentTitle
        self.locationTitle = locationTitle
        self.quantity = quantity
    }
}

@Observable
@MainActor
public final class MoveStockViewModel {
    // MARK: - Properties

    public let itemId: String
    /// Destination parent, nil to move out of any parent
    public let destinationParentId: String?
    public let destinationTitle: String?

    public private(set) var item: StorageItemDetail?
    public private(set) var sources: [StockSource] = []
    public var selectedSourceId: String? {
        didSet {
            if oldValue != selectedSourceId {
                quantity = maxQuantity
            }
        }
    }

    /// Units to move
    public var quantity: Int = 1
    /// Keep the moved units as a separate placement instead of merging with one already in the destination
    public var keepSeparate = false

    public private(set) var isLoading = false
    public private(set) var isSubmitting = false
    public private(set) var error: Error?

    private let preselectedStockId: String?
    private let itemService: ItemServiceProtocol
    private let stockService: ItemStockServiceProtocol

    // MARK: - Initialization

    public init(
        itemId: String,
        destinationParentId: String?,
        destinationTitle: String?,
        preselectedStockId: String? = nil,
        itemService: ItemServiceProtocol = ItemService(),
        stockService: ItemStockServiceProtocol = ItemStockService()
    ) {
        self.itemId = itemId
        self.destinationParentId = destinationParentId
        self.destinationTitle = destinationTitle
        self.preselectedStockId = preselectedStockId
        self.itemService = itemService
        self.stockService = stockService
    }

    // MARK: - Computed Properties

    public var selectedSource: StockSource? {
        sources.first { $0.id == selectedSourceId }
    }

    /// Whether the selected source holds more than one unit, so an amount can be chosen
    public var canChooseAmount: Bool {
        (selectedSource?.quantity ?? 0) > 1
    }

    public var maxQuantity: Int {
        max(selectedSource?.quantity ?? 0, 1)
    }

    public var isMovingAll: Bool {
        quantity >= maxQuantity
    }

    public var remainingQuantity: Int {
        max((selectedSource?.quantity ?? 0) - quantity, 0)
    }

    /// The selected units already sit in the destination parent
    public var isSourceInDestination: Bool {
        selectedSource?.parentId == destinationParentId
    }

    /// Another placement of this item already in the destination
    public var destinationPlacement: StockSource? {
        sources.first { $0.id != selectedSourceId && $0.parentId == destinationParentId }
    }

    /// Placement already in the destination that the moved units will merge into
    public var mergeTarget: StockSource? {
        keepSeparate ? nil : destinationPlacement
    }

    /// Whether choosing between merging and a separate placement matters for this move
    public var canKeepSeparate: Bool {
        destinationPlacement != nil || (isSourceInDestination && canChooseAmount)
    }

    public var destinationDisplayName: String {
        destinationTitle ?? "No parent"
    }

    public var canSubmit: Bool {
        guard !isSubmitting, selectedSource != nil else { return false }
        if isSourceInDestination {
            // Only a split into a separate placement makes sense here
            return keepSeparate && !isMovingAll
        }
        return true
    }

    // MARK: - Public Methods

    public func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let item = try await itemService.fetchItem(id: itemId)
            self.item = item
            sources = Self.makeSources(from: item)
            selectedSourceId = defaultSourceId()
            quantity = maxQuantity
        } catch is CancellationError {
            // View dismissed
        } catch {
            logger.error("Failed to load item for move: \(error.localizedDescription, privacy: .public)")
            self.error = error
        }
    }

    /// Move the chosen units. Returns the server result.
    @discardableResult
    public func submit() async throws -> MoveItemStockResponse {
        guard let source = selectedSource else {
            throw MoveStockError.noSource
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let request = MoveItemStockRequest(
            fromStockId: source.stockId,
            toParentId: destinationParentId,
            quantity: canChooseAmount && !isMovingAll ? quantity : nil,
            merge: keepSeparate ? false : nil
        )
        let movingItemId = itemId
        let destination = destinationParentId ?? "root"
        logger.info("Moving \(request.quantity ?? source.quantity) of \(movingItemId, privacy: .public) to \(destination, privacy: .public)")
        return try await stockService.moveStock(itemId: itemId, request)
    }

    // MARK: - Helpers

    static func makeSources(from item: StorageItemDetail) -> [StockSource] {
        let main = StockSource(
            stockId: nil,
            parentId: item.parentId,
            parentTitle: item.parent?.value1.title,
            locationTitle: item.location?.value1.title,
            quantity: item.mainQuantity
        )
        let placements = item.stocks
            .filter { $0.quantity > 0 }
            .map { stock in
                StockSource(
                    stockId: stock.id,
                    parentId: stock.parentId,
                    parentTitle: stock.parent?.value1.title,
                    locationTitle: stock.location?.value1.title,
                    quantity: stock.quantity
                )
            }
        // Hide an empty main placement when all units live in other placements
        if main.quantity <= 0, !placements.isEmpty {
            return placements
        }
        return [main] + placements
    }

    private func defaultSourceId() -> String? {
        if let preselectedStockId, sources.contains(where: { $0.stockId == preselectedStockId }) {
            return preselectedStockId
        }
        // Prefer units that aren't already in the destination
        return (sources.first { $0.parentId != destinationParentId } ?? sources.first)?.id
    }
}

public enum MoveStockError: LocalizedError {
    case noSource

    public var errorDescription: String? {
        switch self {
        case .noSource:
            return "Choose where to move the item from"
        }
    }
}
