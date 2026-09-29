//
//  AdaptiveRootView.swift
//  RxStorage
//
//  Main view that detects size class and switches between TabBar/Sidebar navigation
//

import RxStorageCore
import SwiftUI

/// Adaptive root view that uses TabView on iPhone and NavigationSplitView on iPad
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationManager = NavigationManager()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone: TabView with TabBar
                TabBarView()
            } else {
                // iPad/macOS: NavigationSplitView with Sidebar
                SidebarNavigationView()
            }
        }
        .environment(navigationManager)
        // Only shown while signed in, so the device token is registered for the current user
        .task {
            #if os(iOS)
                LiveActivityManager.shared.startObserving()
            #endif
            await PushNotificationManager.shared.registerForPushNotifications()
        }
        // Open the ISO job whose notification was tapped, including one that launched the app
        .task(id: PushNotificationManager.shared.pendingIsoJobId) {
            guard let jobId = PushNotificationManager.shared.pendingIsoJobId else { return }
            PushNotificationManager.shared.pendingIsoJobId = nil
            await navigationManager.navigateToIsoJob(id: jobId)
        }
        // Handle universal links (https://...)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let url = userActivity.webpageURL {
                Task {
                    await navigationManager.handleDeepLink(url)
                }
            }
        }
        // Handle custom URL scheme (rxstorage://...)
        .onOpenURL { url in
            Task {
                // Tapping an ISO job's Live Activity opens rxstorage://iso-jobs/<id>
                if let jobId = IsoJobDeepLink.jobId(from: url) {
                    await navigationManager.navigateToIsoJob(id: jobId)
                } else {
                    await navigationManager.handleDeepLink(url)
                }
            }
        }
        .alert("Deep Link Error", isPresented: $navigationManager.showDeepLinkError) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("deep-link-error-ok-button")
        } message: {
            if let error = navigationManager.deepLinkError {
                Text(error.localizedDescription)
                    .accessibilityIdentifier("deep-link-error-message")
            }
        }
        .overlay {
            if navigationManager.isLoadingDeepLink {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Loading item...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    AdaptiveRootView()
}
