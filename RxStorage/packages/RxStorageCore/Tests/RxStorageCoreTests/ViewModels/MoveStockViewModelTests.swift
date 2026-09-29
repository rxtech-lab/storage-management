//
//  MoveStockViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for MoveStockViewModel
//

import Foundation
@testable import RxStorageCore
import Testing

@Suite("MoveStockViewModel Tests")
struct MoveStockViewModelTests {
    // MARK: - Test Data

    static func makeStock(
        id: String,
        parentId: String?,
        parentTitle: String?,
        quantity: Int
    ) -> ItemStock {
        ItemStock(
            id: id,
            itemId: "item",
            parentId: parentId,
            parent: parentId.map { ItemStock.parentPayload(value1: ParentRef(id: $0, title: parentTitle ?? "")) },
            images: [],
            quantity: quantity,
            positions: [],
            createdAt: TestHelpers.defaultDate,
            updatedAt: TestHelpers.defaultDate
        )
    }

    /// Item with 3 units in box A (main) and 2 units in box B
    static let splitItem = TestHelpers.makeStorageItemDetail(
        id: "item",
        title: "Screws",
        parentId: "boxA",
        quantity: 5,
        parent: ParentRef(id: "boxA", title: "Box A"),
        mainQuantity: 3,
        stocks: [makeStock(id: "stockB", parentId: "boxB", parentTitle: "Box B", quantity: 2)]
    )

    @MainActor
    static func makeSUT(
        item: StorageItemDetail,
        destination: String?,
        destinationTitle: String? = nil,
        preselectedStockId: String? = nil
    ) -> (MoveStockViewModel, MockItemStockService) {
        let itemService = MockItemService()
        itemService.fetchItemResult = .success(item)
        let stockService = MockItemStockService()
        let sut = MoveStockViewModel(
            itemId: item.id,
            destinationParentId: destination,
            destinationTitle: destinationTitle,
            preselectedStockId: preselectedStockId,
            itemService: itemService,
            stockService: stockService
        )
        return (sut, stockService)
    }

    // MARK: - Tests

    @Test("Loads main placement and stock placements as sources")
    @MainActor
    func loadsSources() async {
        let (sut, _) = Self.makeSUT(item: Self.splitItem, destination: "boxC", destinationTitle: "Box C")

        await sut.load()

        #expect(sut.sources.map(\.id) == ["main", "stockB"])
        #expect(sut.sources[0].displayName == "Box A")
        #expect(sut.selectedSource?.id == "main")
        #expect(sut.quantity == 3)
        #expect(sut.canChooseAmount)
        #expect(sut.canSubmit)
    }

    @Test("Defaults to a source outside the destination")
    @MainActor
    func defaultsToSourceOutsideDestination() async {
        let (sut, _) = Self.makeSUT(item: Self.splitItem, destination: "boxA", destinationTitle: "Box A")

        await sut.load()

        #expect(sut.selectedSource?.id == "stockB")
        #expect(sut.quantity == 2)
        #expect(sut.mergeTarget?.id == "main")
    }

    @Test("Partial move sends quantity, whole move omits it")
    @MainActor
    func partialAndWholeMoveRequests() async throws {
        let (sut, stockService) = Self.makeSUT(item: Self.splitItem, destination: "boxC")
        await sut.load()

        sut.quantity = 1
        #expect(sut.remainingQuantity == 2)
        try await sut.submit()
        #expect(stockService.lastMoveItemId == "item")
        #expect(stockService.lastMoveRequest?.fromStockId == nil)
        #expect(stockService.lastMoveRequest?.toParentId == "boxC")
        #expect(stockService.lastMoveRequest?.quantity == 1)
        #expect(stockService.lastMoveRequest?.merge == nil)

        sut.quantity = sut.maxQuantity
        try await sut.submit()
        #expect(stockService.lastMoveRequest?.quantity == nil)
    }

    @Test("Changing the source resets the amount to all of its units")
    @MainActor
    func changingSourceResetsQuantity() async {
        let (sut, _) = Self.makeSUT(item: Self.splitItem, destination: "boxC")
        await sut.load()

        sut.quantity = 1
        sut.selectedSourceId = "stockB"

        #expect(sut.quantity == 2)
        #expect(sut.maxQuantity == 2)
    }

    @Test("Units already in the destination can only be split off")
    @MainActor
    func sourceInDestinationRequiresSplit() async throws {
        let item = TestHelpers.makeStorageItemDetail(
            id: "item",
            parentId: "boxA",
            quantity: 4,
            parent: ParentRef(id: "boxA", title: "Box A")
        )
        let (sut, stockService) = Self.makeSUT(item: item, destination: "boxA", destinationTitle: "Box A")
        await sut.load()

        #expect(sut.isSourceInDestination)
        #expect(!sut.canSubmit)
        #expect(sut.canKeepSeparate)

        sut.keepSeparate = true
        #expect(!sut.canSubmit) // moving all units isn't a split
        sut.quantity = 1
        #expect(sut.canSubmit)

        try await sut.submit()
        #expect(stockService.lastMoveRequest?.merge == false)
        #expect(stockService.lastMoveRequest?.quantity == 1)
    }

    @Test("Untracked item moves as a whole")
    @MainActor
    func untrackedItemMovesWhole() async throws {
        let item = TestHelpers.makeStorageItemDetail(id: "item", parentId: nil, quantity: 0)
        let (sut, stockService) = Self.makeSUT(item: item, destination: "boxA")
        await sut.load()

        #expect(sut.sources.count == 1)
        #expect(sut.selectedSource?.displayName == "No parent")
        #expect(!sut.canChooseAmount)
        #expect(sut.canSubmit)

        try await sut.submit()
        #expect(stockService.lastMoveRequest?.quantity == nil)
    }

    @Test("Preselected stock placement is used as the source")
    @MainActor
    func preselectedSource() async {
        let (sut, _) = Self.makeSUT(item: Self.splitItem, destination: nil, preselectedStockId: "stockB")
        await sut.load()

        #expect(sut.selectedSource?.id == "stockB")
        #expect(sut.destinationDisplayName == "No parent")
    }

    @Test("Empty main placement is hidden when units live elsewhere")
    @MainActor
    func hidesEmptyMainPlacement() async {
        let item = TestHelpers.makeStorageItemDetail(
            id: "item",
            parentId: "boxA",
            quantity: 2,
            mainQuantity: 0,
            stocks: [Self.makeStock(id: "stockB", parentId: "boxB", parentTitle: "Box B", quantity: 2)]
        )
        let (sut, _) = Self.makeSUT(item: item, destination: "boxC")
        await sut.load()

        #expect(sut.sources.map(\.id) == ["stockB"])
    }
}
