//
//  PushNotificationManager.swift
//  RxStorage
//
//  Registers the device for APNs and routes notification taps, e.g. to the
//  ISO job that just finished
//

import Observation
import os
import RxStorageCore
import UserNotifications
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

private let logger = Logger(subsystem: "rxlab.RxStorage", category: "PushNotifications")

@Observable
@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    /// ISO job opened from a notification, waiting for the root view to navigate to it
    var pendingIsoJobId: String?

    @ObservationIgnored private let deviceService: DeviceServiceProtocol

    /// Token last registered with the server, kept so it can be removed on sign out
    private static let registeredTokenKey = "registeredPushDeviceToken"

    init(deviceService: DeviceServiceProtocol = DeviceService()) {
        self.deviceService = deviceService
    }

    /// Asks for notification permission and, if granted, registers with APNs.
    /// The token arrives in the app delegate and is forwarded to `didRegister(deviceToken:)`.
    func registerForPushNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
            return
        }

        #if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
            NSApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Sends the APNs token to the server so it can push to this device.
    func didRegister(deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        do {
            _ = try await deviceService.registerDevice(
                DeviceRegisterRequest(token: token, platform: Self.platform, environment: Self.environment)
            )
            UserDefaults.standard.set(token, forKey: Self.registeredTokenKey)
        } catch {
            logger.error("Failed to register device token: \(error.localizedDescription)")
        }
    }

    /// Stops pushes to this device. Call before signing out, while the session is still valid.
    func unregister() async {
        guard let token = UserDefaults.standard.string(forKey: Self.registeredTokenKey) else { return }
        do {
            try await deviceService.unregisterDevice(token: token)
        } catch {
            logger.error("Failed to unregister device token: \(error.localizedDescription)")
        }
        UserDefaults.standard.removeObject(forKey: Self.registeredTokenKey)
    }

    private static var platform: DevicePlatform {
        #if os(macOS)
            .macos
        #else
            .ios
        #endif
    }

    /// Debug builds are signed with the development aps-environment; TestFlight and App Store builds use production.
    private static var environment: DeviceEnvironment {
        #if DEBUG
            .sandbox
        #else
            .production
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Show notifications as banners even while the app is in the foreground
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let jobId = response.notification.request.content.userInfo["isoJobId"] as? String else { return }
        await MainActor.run {
            pendingIsoJobId = jobId
        }
    }
}
