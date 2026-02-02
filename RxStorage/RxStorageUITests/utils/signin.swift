//
//  signin.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/2/26.
//
import XCTest
import os.log

// Use OSLog for better visibility in test output
private let logger = Logger(subsystem: "app.rxlab.RxStorageUITests", category: "signin")

func signInWithEmailAndPassword(for app: XCUIApplication) throws {
    // Read credentials from environment variables
    let testEmail = ProcessInfo.processInfo.environment["TEST_EMAIL"] ?? "test@rxlab.app"
    let testPassword = ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? "default_password"

    NSLog("🔐 Starting sign-in flow with email: \(testEmail)")
    logger.info("🔐 Starting sign-in flow with email: \(testEmail)")

    // Tap sign in button (by accessibility identifier)
    let signInButton = app.buttons["sign-in-button"].firstMatch
    NSLog("⏱️  Waiting for sign-in button...")
    logger.info("⏱️  Waiting for sign-in button...")
    XCTAssertTrue(signInButton.waitForExistence(timeout: 10), "Sign-in button did not appear")
    NSLog("✅ Sign-in button found, tapping...")
    logger.info("✅ Sign-in button found, tapping...")
    signInButton.tap()

    // Give Safari time to launch
    sleep(2)

    // Wait for Safari OAuth page to appear
    let safariViewServiceApp = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
    NSLog("⏱️  Waiting for Safari OAuth page to load...")
    logger.info("⏱️  Waiting for Safari OAuth page to load...")

    // Wait for email field to appear (OAuth page loaded)
    let emailField = safariViewServiceApp.textFields["you@example.com"].firstMatch

    // Use a longer timeout and provide better error message
    let emailFieldExists = emailField.waitForExistence(timeout: 30)
    if !emailFieldExists {
        NSLog("❌ OAuth page did not load. Checking for other elements...")
        logger.error("❌ OAuth page did not load. Checking for other elements...")
        NSLog("Safari windows: \(safariViewServiceApp.windows.count)")
        logger.debug("Safari windows: \(safariViewServiceApp.windows.count)")
        NSLog("Safari web views: \(safariViewServiceApp.webViews.count)")
        logger.debug("Safari web views: \(safariViewServiceApp.webViews.count)")

        // Print all visible elements for debugging
        let allTextFields = safariViewServiceApp.textFields.allElementsBoundByIndex
        NSLog("Visible text fields: \(allTextFields.count)")
        logger.debug("Visible text fields: \(allTextFields.count)")
        for (index, field) in allTextFields.enumerated() {
            let msg = "  Field \(index): \(field.label) - identifier: \(field.identifier)"
            NSLog(msg)
            logger.debug("\(msg)")
        }
    }
    XCTAssertTrue(emailFieldExists, "OAuth login page did not appear within 30 seconds")

    NSLog("✅ Email field found, entering credentials...")
    logger.info("✅ Email field found, entering credentials...")

    // Fill in credentials from environment
    emailField.tap()
    emailField.typeText(testEmail)
    NSLog("✅ Email entered")
    logger.info("✅ Email entered")
    emailField.typeText("\n") // Press Enter to move to next field

    let passwordField = safariViewServiceApp.secureTextFields["Enter your password"].firstMatch
    NSLog("⏱️  Waiting for password field...")
    logger.info("⏱️  Waiting for password field...")
    XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field did not appear")
    NSLog("✅ Password field found, entering password...")
    logger.info("✅ Password field found, entering password...")
    passwordField.tap()
    passwordField.typeText(testPassword)
    NSLog("✅ Password entered, submitting...")
    logger.info("✅ Password entered, submitting...")
    passwordField.typeText("\n") // Press Enter to submit

    NSLog("✅ Sign-in form submitted, waiting for callback...")
    logger.info("✅ Sign-in form submitted, waiting for callback...")

    // Wait a bit for OAuth callback to complete
    sleep(3)
    NSLog("✅ Sign-in flow completed")
    logger.info("✅ Sign-in flow completed")
}
