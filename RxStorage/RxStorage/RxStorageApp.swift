//
//  RxStorageApp.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/27/26.
//

import RxStorageCore
import SwiftUI

@main
struct RxStorageApp: App {
    // Detail view models injected via environment
    @State private var categoryDetailViewModel = CategoryDetailViewModel()
    @State private var authorDetailViewModel = AuthorDetailViewModel()
    @State private var locationDetailViewModel = LocationDetailViewModel()
    @State private var positionSchemaDetailViewModel = PositionSchemaDetailViewModel()
    @State private var eventViewModel = EventViewModel()
    @State private var authManager = OAuthManager(
        configuration: AppConfiguration.shared.rxAuthConfiguration
    )

    init() {
        // Clear tokens if running UI tests with --reset-auth flag
        if CommandLine.arguments.contains("--reset-auth") {
            let tokenStorage = KeychainTokenStorage(serviceName: "com.rxlab.RxStorage")
            try? tokenStorage.clearAll()
        }

        #if DEBUG
            // Handle --test-qr-code launch argument for UI testing
            // This allows tests to inject QR code content without camera access
            if let qrIndex = CommandLine.arguments.firstIndex(of: "--test-qr-code"),
               qrIndex + 1 < CommandLine.arguments.count
            {
                let qrContent = CommandLine.arguments[qrIndex + 1]
                UserDefaults.standard.set(qrContent, forKey: "testQRCodeContent")
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .environment(categoryDetailViewModel)
                .environment(authorDetailViewModel)
                .environment(locationDetailViewModel)
                .environment(positionSchemaDetailViewModel)
                .environment(eventViewModel)
                .environment(authManager)
                .task {
                    await authManager.checkExistingAuth()
                }
        }
        #if os(macOS)
        .defaultSize(width: 500, height: 600)
        .windowResizability(.contentSize)
        #endif
    }
}
