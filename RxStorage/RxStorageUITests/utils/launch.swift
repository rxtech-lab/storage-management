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
    app.launchArguments = ["--reset-auth"]

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
