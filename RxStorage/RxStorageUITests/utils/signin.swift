//
//  signin.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/2/26.
//
import os.log
import XCTest

/// Use OSLog for better visibility in test output
private let logger = Logger(subsystem: "app.rxlab.RxStorageUITests", category: "signin")

extension XCUIApplication {
    func signInWithEmailAndPassword(isAppclips: Bool = false) throws {
        // Load .env file and read credentials (with fallback to process environment for CI)
        let envVars = DotEnv.loadWithFallback()

        let testEmail = DotEnv.get("TEST_EMAIL", from: envVars) ?? "test@rxlab.app"
        NSLog("🔐 Using test email: \(testEmail)")
        guard let testPassword = DotEnv.get("TEST_PASSWORD", from: envVars) else {
            throw NSError(domain: "SigninError", code: 1, userInfo: [NSLocalizedDescriptionKey: "TEST_PASSWORD not found in .env file or environment"])
        }
        NSLog("🔐 Using test password: \(testPassword)")

        NSLog("🔐 Starting sign-in flow with email: \(testEmail)")
        logger.info("🔐 Starting sign-in flow with email: \(testEmail)")

        // If mock auth is active, the app is already authenticated — skip Safari flow
        let signInButton = buttons["sign-in-button"].firstMatch
        if !signInButton.waitForExistence(timeout: 5) {
            NSLog("✅ Mock auth active — already authenticated, skipping Safari sign-in")
            return
        }

        // Tap sign in button (by accessibility identifier)
        NSLog("⏱️  Waiting for sign-in button...")
        logger.info("⏱️  Waiting for sign-in button...")
        NSLog("✅ Sign-in button found, tapping...")
        logger.info("✅ Sign-in button found, tapping...")
        signInButton.tap()

        // Give Safari time to launch
        sleep(2)

        // Wait for Safari OAuth page to appear
        #if os(iOS)
            let safariViewServiceApp = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
            NSLog("⏱️  Waiting for Safari OAuth page to load...")
            logger.info("⏱️  Waiting for Safari OAuth page to load...")

            // Wait for email field to appear (OAuth page loaded)
            let emailField = safariViewServiceApp.textFields["you@example.com"].firstMatch
            let passwordField = safariViewServiceApp.secureTextFields["Enter your password"].firstMatch

            // Use a longer timeout and provide better error message
            let emailFieldExists = emailField.waitForExistence(timeout: 30)
            XCTAssertTrue(emailFieldExists, "Failed to find 'you@example.com' TextField — OAuth page may not have loaded in Safari")
            NSLog("✅ Email field found, entering credentials...")
            logger.info("✅ Email field found, entering credentials...")

            // Fill in credentials from environment
            // WebView elements need extra handling for keyboard focus in CI
            emailField.tap()
            sleep(1) // Give WebView time to establish keyboard focus
            // Type the email
            emailField.typeText(testEmail)
            NSLog("✅ Email entered")
            logger.info("✅ Email entered")

            // Small delay before pressing Enter
            sleep(1)
            emailField.typeText("\n") // Press Enter to move to next field
        #elseif os(macOS)

            let emailField = textFields["you@example.com"].firstMatch
            let emailFieldExists = emailField.waitForExistence(timeout: 30)
            XCTAssertTrue(emailFieldExists, "Failed to sign in and reach dashboard")

            let passwordField = self/*@START_MENU_TOKEN@*/ .secureTextFields["Enter your password"].firstMatch/*[[".groups",".secureTextFields[\"Password\"].firstMatch",".secureTextFields[\"Enter your password\"].firstMatch",".secureTextFields",".containing(.group, identifier: nil).firstMatch",".firstMatch"],[[[-1,2],[-1,1],[-1,3,2],[-1,0,1]],[[-1,2],[-1,1]],[[-1,5],[-1,4]]],[0]]@END_MENU_TOKEN@*/

            emailField.click()
            emailField.typeText(testEmail)
        #endif
        // WebView password field also needs focus handling
        passwordField.tap()
        sleep(1) // Give WebView time to establish keyboard focus

        passwordField.typeText(testPassword)
        NSLog("✅ Password entered, submitting...")
        logger.info("✅ Password entered, submitting...")
        sleep(1)
        passwordField.typeText("\n") // Press Enter to submit

        NSLog("✅ Sign-in form submitted, waiting for callback...")
        logger.info("✅ Sign-in form submitted, waiting for callback...")

        // find dashboard-view
        if !isAppclips {
            let exist = staticTexts["dashboard-view-title"].waitForExistence(timeout: 30)
            XCTAssertTrue(exist, "Failed to sign in and reach dashboard")
        }
    }
}
