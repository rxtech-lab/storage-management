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
        let itemsTab = app.buttons["Items"].firstMatch
        XCTAssertTrue(itemsTab.waitForExistence(timeout: 10), "Items tab did not appear")
        itemsTab.tap()

        // Tap New Item button
        let newItemButton = app.buttons["item-list-new-button"].firstMatch
        XCTAssertTrue(newItemButton.waitForExistence(timeout: 10), "New Item button did not appear")
        newItemButton.tap()

        // Fill in basic info
        let titleField = app.textFields["item-form-title-field"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field did not appear")
        titleField.tap()
        titleField.typeText("Test item")

        let descField = app.textFields["item-form-description-field"].firstMatch
        descField.tap()
        descField.typeText("random description")

        let priceField = app.textFields["item-form-price-field"].firstMatch
        priceField.tap()
        priceField.typeText("10")

        // Submit the item form
        let submitButton = app.buttons["item-form-submit-button"].firstMatch
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5), "Submit button did not appear")
        submitButton.tap()

        // Verify item was created by checking we're back at the list
        XCTAssertTrue(newItemButton.waitForExistence(timeout: 10), "Did not return to item list after creation")

        itemsTab.tap()
        app.buttons["item-row"].firstMatch.tap()

        let itemDetailTitle = app.staticTexts["item-detail-title"].firstMatch
        XCTAssertTrue(itemDetailTitle.waitForExistence(timeout: 20), "Item detail title")
    }

    func delete() throws {
        let app = launchApp()
    }
}
