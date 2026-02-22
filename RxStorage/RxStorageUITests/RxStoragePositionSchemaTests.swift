//
//  RxStoragePositionSchemaTests.swift
//  RxStorage
//
//  UI tests for Position Schema CRUD operations
//

import XCTest

final class RxStoragePositionSchemaTests: XCTestCase {
    /// Navigate from signed-in state to the Position Schemas list
    @MainActor
    private func navigateToSchemaList(app: XCUIApplication) {
        XCTAssertTrue(app.managementTab.waitForExistence(timeout: 10), "Management tab did not appear")
        app.managementTab.tap()

        XCTAssertTrue(app.positionSchemasSection.waitForExistence(timeout: 10), "Position Schemas section did not appear")
        app.positionSchemasSection.tap()
    }

    // MARK: - Create

    @MainActor
    func testCreatePositionSchema() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        navigateToSchemaList(app: app)

        // Tap "+" to open create form
        XCTAssertTrue(app.newSchemaButton.waitForExistence(timeout: 10), "New Schema button did not appear")
        app.newSchemaButton.tap()

        // Fill in name
        XCTAssertTrue(app.schemaFormNameField.waitForExistence(timeout: 5), "Name field did not appear")
        app.schemaFormNameField.tap()
        let schemaName = "Test Schema \(Int.random(in: 1000 ... 9999))"
        app.schemaFormNameField.typeText(schemaName)

        // Dismiss keyboard so we can scroll to Add Property
        app.keyboards.buttons["Return"].firstMatch.tap()
        sleep(1)

        // Scroll down to find Add Property button
        let form = app.collectionViews.firstMatch
        form.swipeUp()

        // Add a property
        XCTAssertTrue(app.schemaEditorAddPropertyButton.waitForExistence(timeout: 5), "Add Property button did not appear")
        app.schemaEditorAddPropertyButton.tap()

        // Fill in property name
        XCTAssertTrue(app.schemaEditorPropertyNameField.waitForExistence(timeout: 5), "Property name field did not appear")
        app.schemaEditorPropertyNameField.tap()
        // Clear the default text and type new name
        app.schemaEditorPropertyNameField.press(forDuration: 1.2)
        let selectAllProp = app.menuItems["Select All"].firstMatch
        if selectAllProp.waitForExistence(timeout: 3) {
            selectAllProp.tap()
        }
        app.schemaEditorPropertyNameField.typeText("shelf")

        // Submit
        XCTAssertTrue(app.schemaFormSubmitButton.waitForExistence(timeout: 5), "Submit button did not appear")
        app.schemaFormSubmitButton.tap()

        // Verify we returned to the list (new button visible again)
        XCTAssertTrue(app.newSchemaButton.waitForExistence(timeout: 10), "Did not return to schema list after creation")
    }

    // MARK: - Read

    @MainActor
    func testViewPositionSchemaDetail() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        navigateToSchemaList(app: app)

        // Wait for at least one row to appear
        XCTAssertTrue(app.schemaRow.firstMatch.waitForExistence(timeout: 10), "No schema rows found in list")
        app.schemaRow.firstMatch.tap()

        // Verify detail view shows the name
        XCTAssertTrue(app.schemaDetailName.waitForExistence(timeout: 10), "Schema detail name did not appear")
    }

    // MARK: - Update

    @MainActor
    func testEditPositionSchema() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        navigateToSchemaList(app: app)

        // Tap first row to open detail
        XCTAssertTrue(app.schemaRow.firstMatch.waitForExistence(timeout: 10), "No schema rows found in list")
        app.schemaRow.firstMatch.tap()

        // Tap edit button
        XCTAssertTrue(app.schemaDetailEditButton.waitForExistence(timeout: 10), "Edit button did not appear")
        app.schemaDetailEditButton.tap()

        // Clear and type new name
        XCTAssertTrue(app.schemaFormNameField.waitForExistence(timeout: 5), "Name field did not appear in edit form")
        app.schemaFormNameField.tap()
        // Select all text and replace
        app.schemaFormNameField.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"].firstMatch
        if selectAll.waitForExistence(timeout: 3) {
            selectAll.tap()
        }
        let updatedName = "Updated Schema \(Int.random(in: 1000 ... 9999))"
        app.schemaFormNameField.typeText(updatedName)

        // Save
        XCTAssertTrue(app.schemaFormSubmitButton.waitForExistence(timeout: 5), "Save button did not appear")
        app.schemaFormSubmitButton.tap()

        // Verify we returned to detail view with updated name
        XCTAssertTrue(app.schemaDetailName.waitForExistence(timeout: 10), "Schema detail name did not appear after edit")
    }

    // MARK: - Delete

    @MainActor
    func testDeletePositionSchema() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        navigateToSchemaList(app: app)

        // First create a schema to delete so we don't remove real data
        XCTAssertTrue(app.newSchemaButton.waitForExistence(timeout: 10), "New Schema button did not appear")
        app.newSchemaButton.tap()

        XCTAssertTrue(app.schemaFormNameField.waitForExistence(timeout: 5), "Name field did not appear")
        app.schemaFormNameField.tap()
        let schemaName = "Delete Me \(Int.random(in: 1000 ... 9999))"
        app.schemaFormNameField.typeText(schemaName)

        // Dismiss keyboard so we can scroll to Add Property
        app.keyboards.buttons["Return"].firstMatch.tap()
        sleep(1)

        // Scroll down and add a property (required for schema validation)
        let form = app.collectionViews.firstMatch
        form.swipeUp()

        XCTAssertTrue(app.schemaEditorAddPropertyButton.waitForExistence(timeout: 5), "Add Property button did not appear")
        app.schemaEditorAddPropertyButton.tap()

        // Fill in property name
        XCTAssertTrue(app.schemaEditorPropertyNameField.waitForExistence(timeout: 5), "Property name field did not appear")
        app.schemaEditorPropertyNameField.tap()
        app.schemaEditorPropertyNameField.press(forDuration: 1.2)
        let selectAllProp = app.menuItems["Select All"].firstMatch
        if selectAllProp.waitForExistence(timeout: 3) {
            selectAllProp.tap()
        }
        app.schemaEditorPropertyNameField.typeText("temp")

        app.schemaFormSubmitButton.tap()

        // Wait for list to reload
        XCTAssertTrue(app.newSchemaButton.waitForExistence(timeout: 10), "Did not return to schema list after creation")
        sleep(2)

        // Swipe delete on the first row
        let firstRow = app.schemaRow.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "No schema rows found to delete")
        firstRow.swipeLeft()

        // Tap the delete button revealed by swipe
        let swipeDeleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 5), "Swipe delete button did not appear")
        swipeDeleteButton.tap()

        // Confirm deletion in the alert
        XCTAssertTrue(app.deleteSchemaAlert.waitForExistence(timeout: 5), "Delete confirmation dialog did not appear")
        app.deleteSchemaConfirmButton.tap()

        // Verify list is still showing (new button exists)
        XCTAssertTrue(app.newSchemaButton.waitForExistence(timeout: 10), "Schema list did not reload after deletion")
    }
}
