//
//  RxStorageItemsTests.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/3/26.
//

import XCTest

final class RxStorageItemsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here
    }

    @MainActor
    func testBasicItemCrud() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // Navigate to Items tab
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 10), "Items tab did not appear")
        app.itemsTab.tap()

        // Tap New Item button
        XCTAssertTrue(app.newItemButton.waitForExistence(timeout: 10), "New Item button did not appear")
        app.newItemButton.tap()

        // Fill in basic info
        XCTAssertTrue(app.itemTitleField.waitForExistence(timeout: 5), "Title field did not appear")
        app.itemTitleField.tap()
        app.itemTitleField.typeText("Test item")

        app.itemDescriptionField.tap()
        app.itemDescriptionField.typeText("random description")

        app.itemPriceField.tap()
        app.itemPriceField.typeText("10")

        // Submit the item form
        XCTAssertTrue(app.itemFormSubmitButton.waitForExistence(timeout: 5), "Submit button did not appear")
        app.itemFormSubmitButton.tap()

        // Verify item was created by checking we're back at the list
        XCTAssertTrue(app.newItemButton.waitForExistence(timeout: 10), "Did not return to item list after creation")

        app.itemsTab.tap()

        app.itemRow.firstMatch.tap()

        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 20), "Item detail title")
    }

    // MARK: - Deep Link Tests

    @MainActor
    func testDeepLinkToPublicItem() throws {
        let app = launchApp()

        // Open deep link to a known public item (same as App Clips test)
        let url = try XCTUnwrap(URL(string: "rxstorage://preview/item/1"))
        app.open(url)

        try app.signInWithEmailAndPassword()

        // Wait for loading to complete
        let loadingOverlay = app.deepLinkLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(loadingOverlay.waitForNonExistence(timeout: 15), "Loading overlay did not disappear")
        }

        // Verify no error alert is shown
        XCTAssertFalse(app.deepLinkErrorAlert.exists, "Deep link error alert should not appear for valid item")

        // Verify item detail is shown
        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 10), "Item detail should be displayed after deep link")
    }

    @MainActor
    func testDeepLinkToPrivateItem() throws {
        let app = launchApp()

        // Open deep link to a known private item (item 2 - requires auth per App Clips test)
        let url = try XCTUnwrap(URL(string: "rxstorage://preview/item/2"))
        app.open(url)

        try app.signInWithEmailAndPassword()

        // Wait for loading to complete
        let loadingOverlay = app.deepLinkLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(loadingOverlay.waitForNonExistence(timeout: 15), "Loading overlay did not disappear")
        }

        // Since we're already signed in, we should see the item detail
        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 10), "Item detail should be displayed for private item when authenticated")
    }

    @MainActor
    func testDeepLinkToPrivateItemBelongsToOthers() throws {
        let app = launchApp()

        // Open deep link to a known private item (item 2 - requires auth per App Clips test)
        let url = try XCTUnwrap(URL(string: "rxstorage://preview/item/3"))
        app.open(url)

        try app.signInWithEmailAndPassword()
        // Wait for error alert to appear
        XCTAssertTrue(app.deepLinkErrorAlert.waitForExistence(timeout: 15), "Deep link error alert should appear for invalid URL")

        // Dismiss the alert
        app.deepLinkErrorOKButton.tap()

        // Verify we're still in the app
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 5), "Should return to main app after dismissing error")
    }

    @MainActor
    func testDeepLinkInvalidUrl() throws {
        let app = launchApp()

        // Open deep link with invalid URL format
        let url = try XCTUnwrap(URL(string: "rxstorage://invalid/path"))
        app.open(url)
        try app.signInWithEmailAndPassword()

        // Wait for error alert to appear
        XCTAssertTrue(app.deepLinkErrorAlert.waitForExistence(timeout: 15), "Deep link error alert should appear for invalid URL")

        // Dismiss the alert
        app.deepLinkErrorOKButton.tap()

        // Verify we're still in the app
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 5), "Should return to main app after dismissing error")
    }

    @MainActor
    func testDeepLinkNonExistentItem() throws {
        let app = launchApp()

        // Open deep link to a non-existent item ID
        let url = try XCTUnwrap(URL(string: "rxstorage://preview/item/999999"))
        app.open(url)

        try app.signInWithEmailAndPassword()
        // Wait for error alert to appear (item not found)
        XCTAssertTrue(app.deepLinkErrorAlert.waitForExistence(timeout: 15), "Deep link error alert should appear for non-existent item")

        // Dismiss the alert
        app.deepLinkErrorOKButton.tap()

        // Verify we're still in the app
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 5), "Should return to main app after dismissing error")
    }
}
