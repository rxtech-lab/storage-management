//
//  RxStorageClipsUITests.swift
//  RxStorageClipsUITests
//
//  Created by Qiwei Li on 1/27/26.
//

import XCTest

final class RxStorageClipsUITests: XCTestCase {
    // MARK: - URL Parsing Tests

    func testInvalidURLShowsError() {
        let app = launchAppClip(withURL: "http://localhost:3000/invalid/path")

        let errorTitle = app.staticTexts["Invalid URL"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: 30))
    }

    // MARK: - Item Loading Tests

    func testPublicItemLoadsSuccessfully() {
        // Use a known public item ID from test environment
        let app = launchAppClip(withItemId: 1)

        // Wait for loading to complete
        let loadingIndicator = app.staticTexts["Loading..."]
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 15))

        // Verify no error state is shown
        let errorTitle = app.staticTexts["Invalid URL"]
        XCTAssertFalse(errorTitle.exists)

        XCTAssertFalse(app.appClipsSignInRequired.exists)

        XCTAssertTrue(app.itemDetailTitle.exists)
    }

    func testPrivateItemRequiresSignIn() throws {
        // Use a known private item ID from test environment
        let app = launchAppClip(withItemId: 2)

        // Wait for auth check to complete and sign-in view to appear
        XCTAssertTrue(app.appClipsSignInRequired.waitForExistence(timeout: 10))

        try app.signInWithEmailAndPassword(isAppclips: true)

        XCTAssertTrue(app.itemDetailTitle.waitForExistence(timeout: 30))
    }

    // MARK: - Error Handling Tests

    func testAccessDenined() throws {
        // This test item created by different users
        let app = launchAppClip(withItemId: 3)
        try app.signInWithEmailAndPassword(isAppclips: true)
        XCTAssertTrue(app.appClipsAccessDenined.waitForExistence(timeout: 30))
    }
}
