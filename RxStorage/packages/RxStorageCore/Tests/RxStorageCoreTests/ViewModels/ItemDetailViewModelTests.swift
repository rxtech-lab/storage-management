//
//  ItemDetailViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for ItemDetailViewModel
//

import Testing
@testable import RxStorageCore

@Suite("ItemDetailViewModel Tests")
struct ItemDetailViewModelTests {

    // MARK: - Test Data

    static let testItem = TestHelpers.makeStorageItem(
        id: 1,
        title: "Test Item",
        description: "Test Description",
        price: 99.99,
        visibility: StorageItem.Visibility.public,
        images: ["https://example.com/image.jpg"]
    )

    static let testChildren = [
        TestHelpers.makeStorageItem(
            id: 2,
            title: "Child Item",
            parentId: 1,
            visibility: StorageItem.Visibility.public
        )
    ]

    // MARK: - Fetch Item Tests

    @Test("Fetch item successfully")
    @MainActor
    func testFetchItemSuccess() async throws {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemResult = .success(Self.testItem)
        mockService.fetchChildrenResult = .success(Self.testChildren)
        let sut = ItemDetailViewModel(itemService: mockService)

        // When
        await sut.fetchItem(id: 1)

        // Then
        #expect(sut.item != nil)
        #expect(sut.item?.id == 1)
        #expect(sut.item?.title == "Test Item")
        #expect(sut.children.count == 1)
        #expect(sut.children[0].title == "Child Item")
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
        #expect(mockService.fetchItemCalled == true)
        #expect(mockService.fetchChildrenCalled == true)
    }

    @Test("Fetch item with error")
    @MainActor
    func testFetchItemError() async throws {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemResult = .failure(APIError.notFound)
        let sut = ItemDetailViewModel(itemService: mockService)

        // When
        await sut.fetchItem(id: 999)

        // Then
        #expect(sut.item == nil)
        #expect(sut.isLoading == false)
        #expect(sut.error != nil)
        #expect(mockService.fetchItemCalled == true)
    }

    // MARK: - Refresh Tests

    @Test("Refresh reloads item")
    @MainActor
    func testRefresh() async throws {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemResult = .success(Self.testItem)
        mockService.fetchChildrenResult = .success([])
        let sut = ItemDetailViewModel(itemService: mockService)

        await sut.fetchItem(id: 1)

        // Reset call tracking
        mockService.fetchItemCalled = false
        mockService.fetchChildrenCalled = false

        // When
        await sut.refresh()

        // Then
        #expect(mockService.fetchItemCalled == true)
    }
}
