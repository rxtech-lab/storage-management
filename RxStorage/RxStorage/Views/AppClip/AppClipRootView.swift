//
//  AppClipRootView.swift
//  RxStorage
//
//  Root view for App Clips - handles deep links and shows view-only ItemDetailView
//

import RxStorageCore
import SwiftUI

/// Root view for App Clips
/// Handles incoming URLs via backend QR code resolution and navigates to ItemDetailView in view-only mode
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

    /// Service for QR code resolution
    private let qrCodeService = QrCodeService()

    /// Store resolved URL for retry after authentication
    @State private var resolvedItemUrl: String?

    /// Store original QR content for retry after authentication (when QR scan itself returns 401)
    @State private var originalQrContent: String?

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
            handleUrl(url)
        }
        .onAppear {
            // Support launch argument for UI testing
            // Launch arguments with format "-key value" are accessible via UserDefaults
            if let urlString = UserDefaults.standard.string(forKey: "AppClipURLKey"),
               let url = URL(string: urlString)
            {
                handleUrl(url)
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
                    // After sign out, retry fetching (no auth since user signed out)
                    if let url = resolvedItemUrl {
                        await fetchItemUsingUrl(url: url)
                    }
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
                    if let url = resolvedItemUrl {
                        await fetchItemUsingUrl(url: url)
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
        handleUrl(url)
    }

    private func handleUrl(_ url: URL) {
        // Send the full URL to backend for resolution
        let qrcontent = url.absoluteString
        Task {
            await fetchItemFromQrCode(qrcontent)
        }
    }

    // MARK: - Fetch Item via QR Code

    private func fetchItemFromQrCode(_ qrcontent: String) async {
        // Reset states
        needsAuth = false
        accessDenied = false
        authError = nil
        parseError = nil

        // Store the original QR content for retry after auth
        originalQrContent = qrcontent

        do {
            // Step 1: Resolve QR code to URL via backend
            let scanResponse = try await qrCodeService.scanQrCode(qrcontent: qrcontent)
            resolvedItemUrl = scanResponse.url

            // Step 2: Fetch item using the URL (auth included if user is signed in)
            await fetchItemUsingUrl(url: scanResponse.url)

        } catch let error as APIError {
            switch error {
            case .unauthorized:
                // QR code scan requires authentication
                needsAuth = true
            case .forbidden:
                // User doesn't have permission to access this item
                accessDenied = true
            case let .unsupportedQRCode(message):
                parseError = message
            default:
                parseError = error.localizedDescription
            }
        } catch {
            parseError = error.localizedDescription
        }
    }

    // MARK: - Fetch Item Using URL

    private func fetchItemUsingUrl(url: String) async {
        // Reset auth states
        needsAuth = false
        accessDenied = false

        // Use ViewModel's method to fetch item (auth included if user is signed in)
        await viewModel.fetchItemUsingUrl(url: url)

        // Check for auth-related errors and update state accordingly
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

        // Update itemId if item was successfully loaded
        if let item = viewModel.item {
            itemId = item.id
        }
    }

    // MARK: - Authentication

    private func signIn() async {
        isAuthenticating = true
        authError = nil

        do {
            try await oauthManager.authenticate()

            // After successful authentication, retry the appropriate step
            if let url = resolvedItemUrl {
                // We already have the resolved URL, just fetch the item (auth included automatically)
                await fetchItemUsingUrl(url: url)
            } else if let qrcontent = originalQrContent {
                // QR scan itself returned 401, retry the entire flow with auth
                await fetchItemFromQrCode(qrcontent)
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

        // Show sign-in view again
        needsAuth = true
    }
}

#Preview {
    AppClipRootView()
}
