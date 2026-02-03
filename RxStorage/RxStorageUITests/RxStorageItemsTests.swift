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
}
