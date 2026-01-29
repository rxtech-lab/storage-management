//
//  ItemFormViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for ItemFormViewModel
//

import Testing
@testable import RxStorageCore

@Suite("ItemFormViewModel Tests")
struct ItemFormViewModelTests {

    // MARK: - Test Data

    static let testItem = TestHelpers.makeStorageItem(
        id: 1,
        title: "Existing Item",
        description: "Existing Description",
        categoryId: 5,
        locationId: 10,
        authorId: 3,
        price: 49.99,
        visibility: StorageItem.Visibility.public,
        images: ["https://example.com/image.jpg"]
    )

    // MARK: - Initialization Tests

    @Test("Initialization with existing item populates form")
    @MainActor
    func testInitializationWithItem() async throws {
        // Given/When
        let sut = ItemFormViewModel(item: Self.testItem)

        // Then
        #expect(sut.title == "Existing Item")
        #expect(sut.description == "Existing Description")
        #expect(sut.selectedCategoryId == 5)
        #expect(sut.selectedLocationId == 10)
        #expect(sut.selectedAuthorId == 3)
        #expect(sut.price == "49.99")
        #expect(sut.visibility == StorageItem.Visibility.public)
        #expect(sut.imageURLs == ["https://example.com/image.jpg"])
    }

    // MARK: - Validation Tests

    @Test("Validation succeeds with valid data")
    @MainActor
    func testValidationSuccess() async throws {
        // Given
        let sut = ItemFormViewModel()
        sut.title = "Valid Title"
        sut.price = "19.99"

        // When
        let isValid = sut.validate()

        // Then
        #expect(isValid == true)
        #expect(sut.validationErrors.isEmpty == true)
    }

    @Test("Validation fails with empty title")
    @MainActor
    func testValidationFailsEmptyTitle() async throws {
        // Given
        let sut = ItemFormViewModel()
        sut.title = ""

        // When
        let isValid = sut.validate()

        // Then
        #expect(isValid == false)
        #expect(sut.validationErrors["title"] == "Title is required")
    }

    @Test("Validation fails with invalid price")
    @MainActor
    func testValidationFailsInvalidPrice() async throws {
        // Given
        let sut = ItemFormViewModel()
        sut.title = "Valid Title"
        sut.price = "invalid"

        // When
        let isValid = sut.validate()

        // Then
        #expect(isValid == false)
        #expect(sut.validationErrors["price"] == "Invalid price format")
    }

    // MARK: - Submit Tests

    @Test("Submit creates new item successfully")
    @MainActor
    func testSubmitCreateSuccess() async throws {
        // Given
        let mockItemService = MockItemService()
        let createdItem = Self.testItem
        mockItemService.createItemResult = .success(createdItem)

        let sut = ItemFormViewModel(
            itemService: mockItemService,
            categoryService: MockCategoryService(),
            locationService: MockLocationService(),
            authorService: MockAuthorService()
        )

        sut.title = "New Item"
        sut.description = "New Description"
        sut.price = "29.99"

        // When
        try await sut.submit()

        // Then
        #expect(mockItemService.createItemCalled == true)
        #expect(mockItemService.lastCreateItemRequest?.title == "New Item")
        #expect(mockItemService.lastCreateItemRequest?.description == "New Description")
        #expect(sut.isSubmitting == false)
    }

    @Test("Submit updates existing item successfully")
    @MainActor
    func testSubmitUpdateSuccess() async throws {
        // Given
        let mockItemService = MockItemService()
        let updatedItem = Self.testItem
        mockItemService.updateItemResult = .success(updatedItem)

        let sut = ItemFormViewModel(
            item: Self.testItem,
            itemService: mockItemService,
            categoryService: MockCategoryService(),
            locationService: MockLocationService(),
            authorService: MockAuthorService()
        )

        sut.title = "Updated Title"

        // When
        try await sut.submit()

        // Then
        #expect(mockItemService.updateItemCalled == true)
        #expect(mockItemService.lastUpdateItemId == 1)
        #expect(mockItemService.lastUpdateItemRequest?.title == "Updated Title")
        #expect(sut.isSubmitting == false)
    }

    @Test("Submit fails validation")
    @MainActor
    func testSubmitFailsValidation() async throws {
        // Given
        let mockItemService = MockItemService()
        let sut = ItemFormViewModel(itemService: mockItemService)
        sut.title = "" // Invalid

        // When/Then
        do {
            try await sut.submit()
            Issue.record("Expected FormError.validationFailed")
        } catch {
            #expect(error is FormError)
        }

        #expect(mockItemService.createItemCalled == false)
    }

    // MARK: - Inline Creation Tests

    @Test("Create category inline")
    @MainActor
    func testCreateCategoryInline() async throws {
        // Given
        let mockCategoryService = MockCategoryService()
        let newCategory = RxStorageCore.Category(id: 99, name: "New Category", description: nil)
        mockCategoryService.createCategoryResult = Result<RxStorageCore.Category, Error>.success(newCategory)

        let sut = ItemFormViewModel(
            itemService: MockItemService(),
            categoryService: mockCategoryService,
            locationService: MockLocationService(),
            authorService: MockAuthorService()
        )

        // When
        let created = try await sut.createCategory(name: "New Category", description: nil)

        // Then
        #expect(created.name == "New Category")
        #expect(sut.categories.contains(where: { $0.id == 99 }))
        #expect(mockCategoryService.createCategoryCalled == true)
    }
}
