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
                await navigationManager.handleDeepLink(url)
            }
        }
        .alert("Deep Link Error", isPresented: $navigationManager.showDeepLinkError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = navigationManager.deepLinkError {
                Text(error.localizedDescription)
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
