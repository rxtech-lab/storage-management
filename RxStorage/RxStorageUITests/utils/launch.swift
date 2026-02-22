//
//  launch.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/2/26.
//
import XCTest

func launchApp() -> XCUIApplication {
    let app = XCUIApplication()

    // --reset-auth flag will:
    // 1. Clear stored tokens from Keychain
    // 2. Use ephemeral Safari session (no cached credentials)
    app.launchArguments = ["--reset-auth", "--ui-testing"]

    app.launch()
    return app
}

/// Launch App Clip with a simulated invocation URL
func launchAppClip(withItemId id: Int) -> XCUIApplication {
    let url = "http://localhost:3000/preview/item/\(id)"
    let app = XCUIApplication()

    app.launchArguments.append("--reset-auth") // Reset auth state for each test
    app.launchArguments.append("-AppClipURLKey") // Custom key for the URL
    app.launchArguments.append(url) // The specific URL you want to test
    app.launch()

    return app
}

/// Launch App Clip with a custom URL
func launchAppClip(withURL url: String) -> XCUIApplication {
    let app = XCUIApplication()

    app.launchArguments.append("-AppClipURLKey") // Custom key for the URL
    app.launchArguments.append(url) // The specific URL you want to test
    app.launchArguments.append("--reset-auth") // Reset auth state for each test
    app.launch()

    return app
}

/// Launch main app and trigger deep link with item ID
/// Uses the custom URL scheme: rxstorage://preview/item/{id}
func launchAppWithDeepLink(itemId id: Int) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("--reset-auth")
    app.launch()

    // Open the deep link URL after app launches
    let url = URL(string: "rxstorage://preview/item/\(id)")!
    app.open(url)

    return app
}

/// Launch main app and trigger deep link with custom URL
func launchAppWithDeepLink(url: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("--reset-auth")
    app.launch()

    // Open the deep link URL after app launches
    if let deepLinkURL = URL(string: url) {
        app.open(deepLinkURL)
    }

    return app
}

/// Launch main app and trigger deep link with HTTP URL (universal link simulation)
func launchAppWithUniversalLink(itemId id: Int) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("--reset-auth")
    app.launch()

    // Open the universal link URL after app launches
    let url = URL(string: "http://localhost:3000/preview/item/\(id)")!
    app.open(url)

    return app
}

/// Launch main app with simulated QR code scan
/// The QR content will be processed when navigating to Items tab
/// - Parameter qrContent: The QR code content to simulate (e.g., "preview/item/1" or full URL)
func launchAppWithQRCode(_ qrContent: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("--reset-auth")
    app.launchArguments.append("--test-qr-code")
    app.launchArguments.append(qrContent)
    app.launch()
    return app
}
