//
//  RxStorageQRScanTests.swift
//  RxStorage
//
//  UI tests for QR code scanning functionality
//

import XCTest

final class RxStorageQRScanTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Cleanup code here
    }

    // MARK: - QR Scanner Button Tests

    @MainActor
    func testQRScannerButtonExists() throws {
        let app = launchApp()
        try app.signInWithEmailAndPassword()

        // Navigate to Items tab
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 10), "Items tab did not appear")
        app.itemsTab.tap()

        // Verify QR scanner button exists in toolbar
        XCTAssertTrue(
            app.qrScannerButton.waitForExistence(timeout: 5),
            "QR scanner button should exist in toolbar"
        )
    }

    // MARK: - QR Code Scan Tests (Via Injection)

    /// Test scanning QR code for public item (item 1)
    /// Expected: Item detail should be displayed
    @MainActor
    func testQRCodeScanPublicItem() throws {
        // Launch app with injected QR code content for public item 1
        let qrContent = "http://localhost:3000/preview/item?id=1"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        XCTAssertTrue(app.itemsTab.waitForExistence(timeout: 10), "Items tab did not appear")
        app.itemsTab.tap()

        // Wait for QR code loading to complete
        let loadingOverlay = app.qrCodeLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(
                loadingOverlay.waitForNonExistence(timeout: 15),
                "QR code loading overlay did not disappear"
            )
        }

        // Verify no error alert is shown
        XCTAssertFalse(app.errorAlert.exists, "Error alert should not appear for valid public item")

        // Verify item detail is shown
        XCTAssertTrue(
            app.itemDetailTitle.waitForExistence(timeout: 10),
            "Item detail should be displayed after QR scan"
        )
    }

    /// Test scanning QR code for private item (item 2) when authenticated
    /// Expected: Item detail should be displayed for authenticated user
    @MainActor
    func testQRCodeScanPrivateItemAuthenticated() throws {
        // Launch app with injected QR code content for private item 2
        let qrContent = "http://localhost:3000/preview/item?id=2"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        app.itemsTab.tap()

        // Wait for QR code loading to complete
        let loadingOverlay = app.qrCodeLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(
                loadingOverlay.waitForNonExistence(timeout: 15),
                "QR code loading overlay did not disappear"
            )
        }

        // Verify item detail is shown (user is authenticated)
        XCTAssertTrue(
            app.itemDetailTitle.waitForExistence(timeout: 10),
            "Authenticated user should see private item detail after QR scan"
        )
    }

    /// Test scanning QR code for private item belonging to others (item 3)
    /// Expected: Error alert should appear (403 Forbidden)
    @MainActor
    func testQRCodeScanPrivateItemAccessDenied() throws {
        // Launch app with injected QR code content for private item 3 (belongs to others)
        let qrContent = "http://localhost:3000/preview/item?id=3"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        app.itemsTab.tap()

        // Wait for error alert to appear (403 - access denied)
        XCTAssertTrue(
            app.errorAlert.waitForExistence(timeout: 15),
            "Error alert should appear for access denied item"
        )

        // Dismiss the alert
        app.errorAlertOKButton.tap()

        // Verify we're still on the Items tab
        XCTAssertTrue(
            app.qrScannerButton.waitForExistence(timeout: 5),
            "Should remain on Items tab after dismissing error"
        )
    }

    /// Test scanning invalid QR code content
    /// Expected: Error alert should appear (400 Bad Request)
    @MainActor
    func testQRCodeScanInvalidContent() throws {
        // Launch app with invalid QR code content
        let qrContent = "invalid-qr-content-not-a-url"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        app.itemsTab.tap()

        // Wait for error alert to appear (400 - bad request)
        XCTAssertTrue(
            app.errorAlert.waitForExistence(timeout: 15),
            "Error alert should appear for invalid QR content"
        )

        // Dismiss the alert
        app.errorAlertOKButton.tap()

        // Verify we're still on the Items tab
        XCTAssertTrue(
            app.qrScannerButton.waitForExistence(timeout: 5),
            "Should remain on Items tab after dismissing error"
        )
    }

    /// Test scanning QR code for non-existent item
    /// Expected: Error alert should appear (404 Not Found)
    @MainActor
    func testQRCodeScanNonExistentItem() throws {
        // Launch app with QR code content for non-existent item
        let qrContent = "http://localhost:3000/preview/item?id=999999"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        app.itemsTab.tap()

        // Wait for error alert to appear (404 - not found)
        XCTAssertTrue(
            app.errorAlert.waitForExistence(timeout: 15),
            "Error alert should appear for non-existent item"
        )

        // Dismiss the alert
        app.errorAlertOKButton.tap()

        // Verify we're still on the Items tab
        XCTAssertTrue(
            app.qrScannerButton.waitForExistence(timeout: 5),
            "Should remain on Items tab after dismissing error"
        )
    }

    /// Test scanning QR code with relative path format
    /// Expected: Item detail should be displayed (backend supports this format)
    @MainActor
    func testQRCodeScanRelativePath() throws {
        // Launch app with relative path QR code content
        let qrContent = "preview/item?id=1"
        let app = launchAppWithQRCode(qrContent)

        try app.signInWithEmailAndPassword()

        // Navigate to Items tab - this triggers QR code processing
        app.itemsTab.tap()

        // Wait for QR code loading to complete
        let loadingOverlay = app.qrCodeLoadingOverlay
        if loadingOverlay.waitForExistence(timeout: 2) {
            XCTAssertTrue(
                loadingOverlay.waitForNonExistence(timeout: 15),
                "QR code loading overlay did not disappear"
            )
        }

        // Verify item detail is shown
        XCTAssertTrue(
            app.itemDetailTitle.waitForExistence(timeout: 10),
            "Item detail should be displayed for relative path QR code"
        )
    }
}
