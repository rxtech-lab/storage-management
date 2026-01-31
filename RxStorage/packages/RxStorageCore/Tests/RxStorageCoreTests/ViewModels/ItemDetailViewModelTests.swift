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

    static let defaultDate: Date = {
        ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!
    }()

    static let testContent = Content(
        id: 1,
        itemId: 1,
        type: .image,
        data: ContentData(title: "Test Image", description: "A test image"),
        createdAt: defaultDate,
        updatedAt: defaultDate
    )

    static let testChild = TestHelpers.makeStorageItem(
        id: 2,
        title: "Child Item",
        parentId: 1,
        visibility: StorageItem.Visibility.public
    )

    static let testItem = TestHelpers.makeStorageItem(
        id: 1,
        title: "Test Item",
        description: "Test Description",
        price: 99.99,
        visibility: StorageItem.Visibility.public,
        images: ["https://example.com/image.jpg"],
        children: [testChild],
        contents: [testContent]
    )

    // MARK: - Fetch Item Tests

    @Test("Fetch item successfully with children and contents")
    @MainActor
    func testFetchItemSuccess() async throws {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemResult = .success(Self.testItem)
        let sut = ItemDetailViewModel(itemService: mockService)

        // When
        await sut.fetchItem(id: 1)

        // Then
        #expect(sut.item != nil)
        #expect(sut.item?.id == 1)
        #expect(sut.item?.title == "Test Item")
        #expect(sut.children.count == 1)
        #expect(sut.children[0].title == "Child Item")
        #expect(sut.contents.count == 1)
        #expect(sut.contents[0].type == .image)
        #expect(sut.contents[0].data.title == "Test Image")
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
        #expect(mockService.fetchItemCalled == true)
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
        let sut = ItemDetailViewModel(itemService: mockService)

        await sut.fetchItem(id: 1)

        // Reset call tracking
        mockService.fetchItemCalled = false

        // When
        await sut.refresh()

        // Then
        #expect(mockService.fetchItemCalled == true)
    }
}
