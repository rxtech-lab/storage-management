//
//  AppDelegate.swift
//  RxStorage
//
//  Receives APNs registration callbacks, which SwiftUI does not expose
//

import os
import UserNotifications
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

private let logger = Logger(subsystem: "rxlab.RxStorage", category: "PushNotifications")

#if os(iOS)
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(
            _: UIApplication,
            willFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            // Set before launch finishes so taps that launched the app are delivered
            UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
            return true
        }

        func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Task {
                await PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
            }
        }

        func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
            logger.error("APNs registration failed: \(error.localizedDescription)")
        }
    }

#elseif os(macOS)
    final class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationWillFinishLaunching(_: Notification) {
            // Set before launch finishes so taps that launched the app are delivered
            UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        }

        func application(_: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Task {
                await PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
            }
        }

        func application(_: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
            logger.error("APNs registration failed: \(error.localizedDescription)")
        }
    }
#endif
