//
//  CategoryListViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for CategoryListViewModel
//

@testable import RxStorageCore
import Testing

@Suite("CategoryListViewModel Tests")
struct CategoryListViewModelTests {
    // MARK: - Test Data

    static let testCategories = [
        TestHelpers.makeCategory(id: 1, name: "Books", description: "Book category"),
        TestHelpers.makeCategory(id: 2, name: "Electronics", description: "Electronics category"),
    ]

    // MARK: - Fetch Tests

    @Test("Fetch categories successfully")
    @MainActor
    func fetchCategoriesSuccess() async {
        // Given
        let mockService = MockCategoryService()
        mockService.fetchCategoriesResult = .success(Self.testCategories)
        let sut = CategoryListViewModel(categoryService: mockService)

        // When
        await sut.fetchCategories()

        // Then
        #expect(sut.categories.count == 2)
        #expect(sut.categories[0].name == "Books")
        #expect(sut.categories[1].name == "Electronics")
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
        #expect(mockService.fetchCategoriesCalled == true)
    }

    @Test("Fetch categories with error")
    @MainActor
    func fetchCategoriesError() async {
        // Given
        let mockService = MockCategoryService()
        mockService.fetchCategoriesResult = .failure(APIError.serverError("Test error"))
        let sut = CategoryListViewModel(categoryService: mockService)

        // When
        await sut.fetchCategories()

        // Then
        #expect(sut.categories.isEmpty)
        #expect(sut.isLoading == false)
        #expect(sut.error != nil)
    }

    // MARK: - Search Tests

    @Test("Search updates searchText and triggers search")
    @MainActor
    func testSearch() {
        // Given
        let mockService = MockCategoryService()
        mockService.fetchCategoriesResult = .success(Self.testCategories)
        let sut = CategoryListViewModel(categoryService: mockService)

        // When
        sut.search("book")

        // Then
        #expect(sut.searchText == "book")
        // Note: The actual API call is debounced, so we just verify the search method works
    }

    // MARK: - Delete Tests

    @Test("Delete category successfully")
    @MainActor
    func deleteCategorySuccess() async throws {
        // Given
        let mockService = MockCategoryService()
        mockService.fetchCategoriesResult = .success(Self.testCategories)
        mockService.deleteCategoryResult = .success(())
        let sut = CategoryListViewModel(categoryService: mockService)

        await sut.fetchCategories()
        let categoryToDelete = sut.categories[0]

        // When
        try await sut.deleteCategory(categoryToDelete)

        // Then
        #expect(sut.categories.count == 1)
        #expect(sut.categories[0].id == 2)
        #expect(mockService.deleteCategoryCalled == true)
        #expect(mockService.lastDeleteCategoryId == 1)
    }
}
