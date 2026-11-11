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

        let editButton = app.navigationBars["Test Location"].buttons["Edit"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        let cancelButton = app.buttons["location-form-cancel-button"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        XCTAssertTrue(cancelButton.waitForNonExistence(timeout: 5))

        let locationList = app.collectionViews["location-info-list"].firstMatch
        let itemsButton = app.buttons["location-items-button"].firstMatch
        let doneButton = app.buttons["entity-items-done-button"].firstMatch

        func openItemsSheet() {
            XCTAssertTrue(locationList.waitForExistence(timeout: 10), "Location info should be visible")
            // Dismissing edit restores the compact info sheet at its initial detent.
            // Expand and scroll that list instead of tapping an offscreen cached header.
            let grabber = app.buttons["Sheet Grabber"].firstMatch
            if grabber.exists {
                grabber.swipeUp()
            }
            locationList.swipeUp()
            for _ in 0 ..< 8 {
                let visibleFrame = locationList.frame.intersection(app.frame)
                if itemsButton.exists, itemsButton.isHittable,
                   visibleFrame.contains(itemsButton.frame) { break }
                locationList.swipeUp()
            }
            XCTAssertTrue(itemsButton.isHittable, "Items header should be visible before tapping")
            itemsButton.tap()
            XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Items sheet should present its Done button")
        }

        openItemsSheet()
        doneButton.tap()
        XCTAssertTrue(doneButton.waitForNonExistence(timeout: 5), "Done should dismiss the items sheet")

        openItemsSheet()
        let itemLink = app.buttons["entity-item-link-test-public-item"].firstMatch
        XCTAssertTrue(itemLink.waitForExistence(timeout: 10), "Items sheet should contain the seeded item")
        itemLink.tap()
        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 10), "Item detail should open inside the sheet")

        let backButton = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label == %@",
            "BackButton", "Items at Location"
        )).firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Returning from the item should restore the items sheet")
        doneButton.tap()
        XCTAssertTrue(locationList.waitForExistence(timeout: 10), "Dismissing items should restore location info")
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
