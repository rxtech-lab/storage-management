//
//  AppClipRootView.swift
//  RxStorage
//
//  Root view for App Clips - handles deep links and shows view-only ItemDetailView
//

import RxStorageCore
import SwiftUI

/// Root view for App Clips
/// Parses the incoming URL and navigates directly to ItemDetailView in view-only mode
/// Implements proper auth flow:
/// 1. First try to fetch item without auth (works for public items)
/// 2. If 401, show sign-in button
/// 3. After sign-in, retry fetching
/// 4. If 403, show access denied
struct AppClipRootView: View {
    @State private var itemId: Int?
    @State private var parseError: String?
    @State private var viewModel = ItemDetailViewModel()
    @State private var oauthManager = OAuthManager()

    // Auth flow states
    @State private var needsAuth = false
    @State private var accessDenied = false
    @State private var isAuthenticating = false
    @State private var authError: String?

    /// Sign out confirmation state
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if needsAuth {
                    AppClipSignInView(
                        authError: authError,
                        isAuthenticating: isAuthenticating,
                        onSignIn: { Task { await signIn() } }
                    )
                } else if accessDenied {
                    AppClipAccessDeniedView(
                        userEmail: oauthManager.currentUser?.email,
                        onTryDifferentAccount: { Task { await tryDifferentAccount() } }
                    )
                } else if let error = parseError {
                    ContentUnavailableView(
                        "Invalid URL",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .accessibilityIdentifier("invalid-url")
                } else if viewModel.isLoading {
                    loadingView
                } else if let id = itemId, viewModel.item != nil {
                    itemDetailView(id: id)
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else if itemId == nil {
                    ProgressView("Waiting for URL...")
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationDestination(for: StorageItem.self) { child in
                ItemDetailView(itemId: child.id, isViewOnly: true)
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            handleUserActivity(userActivity)
        }
        .onOpenURL { url in
            parseItemId(from: url)
        }
        .onAppear {
            // Support launch argument for UI testing
            // Launch arguments with format "-key value" are accessible via UserDefaults
            if let urlString = UserDefaults.standard.string(forKey: "AppClipURLKey"),
               let url = URL(string: urlString)
            {
                parseItemId(from: url)
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        ZStack {
            AnimatedGradientBackground()
            ProgressView("Loading...")
        }
    }

    private func itemDetailView(id: Int) -> some View {
        ItemDetailView(itemId: id, isViewOnly: true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showSignOutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                title: "Sign Out",
                message: "Are you sure you want to sign out?",
                confirmButtonTitle: "Sign Out",
                isPresented: $showSignOutConfirmation
            ) {
                Task {
                    try? await TokenStorage.shared.clearAll()
                    await oauthManager.logout()
                    await fetchItem(id)
                }
            }
    }

    private func errorView(error: Error) -> some View {
        VStack {
            ContentUnavailableView(
                "Error Loading Item",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )

            Button("Retry") {
                Task {
                    if let id = itemId {
                        await fetchItem(id)
                    }
                }
            }
        }
    }

    // MARK: - URL Handling

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else {
            parseError = "No URL provided"
            return
        }
        parseItemId(from: url)
    }

    private func parseItemId(from url: URL) {
        // QR codes use: https://storage.rxlab.app/preview/item/{id}
        let pathComponents = url.pathComponents

        // Path format: ["", "preview", "item", "123"]
        if pathComponents.count >= 4,
           pathComponents[1] == "preview",
           pathComponents[2] == "item",
           let id = Int(pathComponents[3])
        {
            itemId = id
            Task {
                await fetchItem(id)
            }
            return
        }

        parseError = "Could not extract item ID from URL"
    }

    // MARK: - Fetch Item

    private func fetchItem(_ id: Int) async {
        // Reset states
        needsAuth = false
        accessDenied = false
        authError = nil

        // Use the preview endpoint which supports public access
        await viewModel.fetchPreviewItem(id: id)

        // Check for auth-related errors
        if let error = viewModel.error as? APIError {
            switch error {
            case .unauthorized:
                needsAuth = true
            case .forbidden:
                accessDenied = true
            default:
                break
            }
        }
    }

    // MARK: - Authentication

    private func signIn() async {
        isAuthenticating = true
        authError = nil

        do {
            try await oauthManager.authenticate()

            // After successful authentication, retry fetching the item
            if let id = itemId {
                await fetchItem(id)
            }
        } catch {
            authError = error.localizedDescription
        }

        isAuthenticating = false
    }

    private func tryDifferentAccount() async {
        // Clear tokens and sign out
        try? await TokenStorage.shared.clearAll()
        await oauthManager.logout()

        // Retry fetching the item (will show sign-in view again)
        if let id = itemId {
            await fetchItem(id)
        }
    }
}

#Preview {
    AppClipRootView()
}
