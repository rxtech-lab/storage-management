//
//  RxStorageTagNavigationTests.swift
//  RxStorage
//
//  UI tests for entity detail navigation flow
//

import XCTest

final class RxStorageEntityNavigationTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Deep link to test-public-item and wait for item detail to load
    @MainActor
    private func navigateToTestItem(app: XCUIApplication) throws {
        let url = try XCTUnwrap(URL(string: "rxstorage://preview/item?id=test-public-item"))
        app.open(url)

        try app.signInWithEmailAndPassword()

        let loadingOverlay = app.deepLinkLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(loadingOverlay.waitForNonExistence(timeout: 15), "Loading overlay did not disappear")
        }

        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 10), "Item detail should be displayed")
    }

    /// Scroll down to find an element
    @MainActor
    private func scrollToFind(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        var attempts = 0
        while !element.exists, attempts < 5 {
            scrollView.swipeUp()
            attempts += 1
        }
    }

    // MARK: - Tag Navigation

    @MainActor
    func testNavigateFromItemToTagToItem() throws {
        let app = launchApp()
        try navigateToTestItem(app: app)

        // Find and tap the tag row
        let tagElement = app.descendants(matching: .any)["tag-row-test-tag-1"].firstMatch
        scrollToFind(tagElement, in: app)
        XCTAssertTrue(tagElement.waitForExistence(timeout: 5), "Tag row should exist on item detail")
        tagElement.tap()

        // Verify tag detail view appears
        XCTAssertTrue(app.tagDetailTitle.waitForExistence(timeout: 10), "Tag detail should be displayed")

        // Tap an item in the tag's items list
        let itemRowInTag = app.staticTexts["item-row"].firstMatch
        XCTAssertTrue(itemRowInTag.waitForExistence(timeout: 10), "Item row in tag detail should exist")
        itemRowInTag.tap()

        // Verify we navigated to item detail
        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 10), "Should navigate to item detail from tag")
    }

    // MARK: - Category Navigation

    @MainActor
    func testNavigateFromItemToCategory() throws {
        let app = launchApp()
        try navigateToTestItem(app: app)

        // Find and tap the category link
        scrollToFind(app.detailCategoryLink, in: app)
        XCTAssertTrue(app.detailCategoryLink.waitForExistence(timeout: 5), "Category link should exist on item detail")
        app.detailCategoryLink.tap()

        // Verify category detail view appears
        XCTAssertTrue(app.categoryDetailTitle.waitForExistence(timeout: 10), "Category detail should be displayed")
    }

    // MARK: - Location Navigation

    @MainActor
    func testNavigateFromItemToLocation() throws {
        let app = launchApp()
        try navigateToTestItem(app: app)

        // Find and tap the location link
        scrollToFind(app.detailLocationLink, in: app)
        XCTAssertTrue(app.detailLocationLink.waitForExistence(timeout: 5), "Location link should exist on item detail")
        app.detailLocationLink.tap()

        // Verify location detail view appears
        XCTAssertTrue(app.staticTexts["Test Location"].waitForExistence(timeout: 10), "Location detail should be displayed")

        app/*@START_MENU_TOKEN@*/ .buttons["Edit"]/*[[".navigationBars.buttons[\"Edit\"]",".buttons[\"Edit\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()
        app/*@START_MENU_TOKEN@*/ .buttons["location-form-cancel-button"]/*[[".otherElements[\"location-form-cancel-button\"].buttons",".otherElements",".buttons[\"Cancel\"]",".buttons[\"location-form-cancel-button\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()

        let cellsQuery = app.cells
        cellsQuery/*@START_MENU_TOKEN@*/ .containing(.staticText, identifier: "Test Location").firstMatch/*[[".element(boundBy: 0)",".containing(.staticText, identifier: \"37.774900, -122.419400\").firstMatch",".containing(.staticText, identifier: \"Test Location\").firstMatch"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .swipeUp()

        let element = app/*@START_MENU_TOKEN@*/ .buttons["Items, (1)"]/*[[".buttons",".containing(.image, identifier: \"chevron.right\")",".containing(.staticText, identifier: \"(1)\")",".containing(.staticText, identifier: \"Items\")",".otherElements.buttons[\"Items, (1)\"]",".buttons[\"Items, (1)\"]"],[[[-1,5],[-1,4],[-1,0,1]],[[-1,3],[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch

        app.collectionViews/*@START_MENU_TOKEN@*/ .firstMatch/*[[".containing(.cell, identifier: nil).firstMatch",".containing(.other, identifier: nil).firstMatch",".firstMatch"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .swipeUp()
        cellsQuery/*@START_MENU_TOKEN@*/ .containing(.staticText, identifier: "Latitude").firstMatch/*[[".element(boundBy: 2)",".containing(.staticText, identifier: \"37.774900\").firstMatch",".containing(.staticText, identifier: \"Latitude\").firstMatch"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .swipeUp()
        app/*@START_MENU_TOKEN@*/ .buttons["item-row"]/*[[".buttons",".containing(.image, identifier: \"chevron.forward\")",".containing(.staticText, identifier: \"This is a public test item for E2E testing\")",".containing(.staticText, identifier: \"item-row\")",".otherElements",".buttons[\"Public Test Item, This is a public test item for E2E testing\"]",".buttons[\"item-row\"]"],[[[-1,6],[-1,5],[-1,4,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1]],[[-1,6],[-1,5]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()

        app.staticTexts["Test Category"].firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        app.staticTexts["Test Author"].firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        app/*@START_MENU_TOKEN@*/ .buttons["BackButton"]/*[[".navigationBars",".buttons[\"Back\"]",".buttons[\"BackButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()

        element.tap()

        let element2 = app/*@START_MENU_TOKEN@*/ .buttons["Done"]/*[[".otherElements[\"Done\"].buttons",".otherElements.buttons[\"Done\"]",".buttons[\"Done\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch
        element2.tap()
        app/*@START_MENU_TOKEN@*/ .buttons["item-row"]/*[[".buttons",".containing(.image, identifier: \"chevron.forward\")",".containing(.staticText, identifier: \"This is a public test item for E2E testing\")",".containing(.staticText, identifier: \"item-row\")",".cells.buttons",".otherElements",".buttons[\"Public Test Item, This is a public test item for E2E testing\"]",".buttons[\"item-row\"]"],[[[-1,7],[-1,6],[-1,5,2],[-1,4],[-1,0,1]],[[-1,3],[-1,2],[-1,1]],[[-1,7],[-1,6]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()
        app/*@START_MENU_TOKEN@*/ .buttons["BackButton"]/*[[".navigationBars",".buttons[\"Items at Location\"]",".buttons[\"BackButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.tap()
        element2.tap()
    }

    // MARK: - Author Navigation

    @MainActor
    func testNavigateFromItemToAuthor() throws {
        let app = launchApp()
        try navigateToTestItem(app: app)

        // Find and tap the author link (should be visible without scrolling since it's in Details card)
        XCTAssertTrue(app.detailAuthorLink.waitForExistence(timeout: 5), "Author link should exist on item detail")
        app.detailAuthorLink.tap()

        // Verify author detail view appears
        XCTAssertTrue(app.authorDetailTitle.waitForExistence(timeout: 10), "Author detail should be displayed")
    }
}
