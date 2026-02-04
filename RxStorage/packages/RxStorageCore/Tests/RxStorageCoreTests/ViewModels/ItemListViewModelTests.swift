//
//  ItemListViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for ItemListViewModel
//

@testable import RxStorageCore
import Testing

@Suite("ItemListViewModel Tests")
struct ItemListViewModelTests {
    // MARK: - Test Data

    static let testItems = [
        TestHelpers.makeStorageItem(
            id: 1,
            title: "Test Item 1",
            description: "Description 1",
            visibility: .publicAccess
        ),
        TestHelpers.makeStorageItem(
            id: 2,
            title: "Test Item 2",
            description: "Description 2",
            price: 99.99,
            visibility: .privateAccess
        ),
    ]

    // MARK: - Fetch Items Tests

    @Test("Fetch items successfully")
    @MainActor
    func fetchItemsSuccess() async {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemsResult = .success(Self.testItems)
        let sut = ItemListViewModel(itemService: mockService)

        // When
        await sut.fetchItems()

        // Then
        #expect(sut.items.count == 2)
        #expect(sut.items[0].title == "Test Item 1")
        #expect(sut.items[1].title == "Test Item 2")
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
        #expect(mockService.fetchItemsCalled == true)
    }

    @Test("Fetch items with error")
    @MainActor
    func fetchItemsError() async {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemsResult = .failure(APIError.serverError("Test error"))
        let sut = ItemListViewModel(itemService: mockService)

        // When
        await sut.fetchItems()

        // Then
        #expect(sut.items.isEmpty)
        #expect(sut.isLoading == false)
        #expect(sut.error != nil)
        #expect(mockService.fetchItemsCalled == true)
    }

    // MARK: - Search Tests

    @Test("Search text updates filters")
    @MainActor
    func searchTextUpdatesFilters() {
        // Given
        let mockService = MockItemService()
        let sut = ItemListViewModel(itemService: mockService)

        // When
        sut.search("test query")

        // Then - search method updates searchText
        #expect(sut.searchText == "test query")
        // Note: filters.search is updated after debounce and performSearch call
    }

    @Test("Empty search text clears search filter")
    @MainActor
    func emptySearchTextClearsFilter() {
        // Given
        let mockService = MockItemService()
        let sut = ItemListViewModel(itemService: mockService)
        sut.search("test query")

        // When
        sut.search("")

        // Then
        #expect(sut.searchText == "")
    }

    // MARK: - Delete Item Tests

    @Test("Delete item successfully")
    @MainActor
    func deleteItemSuccess() async throws {
        // Given
        let mockService = MockItemService()
        mockService.fetchItemsResult = .success(Self.testItems)
        mockService.deleteItemResult = .success(())
        let sut = ItemListViewModel(itemService: mockService)

        await sut.fetchItems()
        let itemToDelete = sut.items[0]

        // When
        try await sut.deleteItem(itemToDelete)

        // Then
        #expect(sut.items.count == 1)
        #expect(sut.items[0].id == 2)
        #expect(mockService.deleteItemCalled == true)
        #expect(mockService.lastDeleteItemId == 1)
    }

    // MARK: - Clear Filters Tests

    @Test("Clear filters resets all filters")
    @MainActor
    func testClearFilters() {
        // Given
        let mockService = MockItemService()
        let sut = ItemListViewModel(itemService: mockService)
        sut.searchText = "test"
        sut.filters.categoryId = 1
        sut.filters.visibility = .publicAccess

        // When
        sut.clearFilters()

        // Then
        #expect(sut.searchText == "")
        #expect(sut.filters.categoryId == nil)
        #expect(sut.filters.visibility == nil)
        #expect(sut.filters.isEmpty == true)
    }
}
