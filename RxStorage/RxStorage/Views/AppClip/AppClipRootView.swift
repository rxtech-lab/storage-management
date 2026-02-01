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

    // Animation states for sign-in view
    @State private var showSignInTitle = false
    @State private var showSignInButton = false

    // Animation states for access denied view
    @State private var showDeniedTitle = false
    @State private var showDeniedButton = false

    // Sign out confirmation state
    @State private var showSignOutConfirmation = false
    @State private var showTryDifferentAccountConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if needsAuth {
                    // Show sign-in view when authentication is required
                    signInView
                } else if accessDenied {
                    // Show access denied error
                    accessDeniedView
                } else if let error = parseError {
                    // Show error if URL parsing failed
                    ContentUnavailableView(
                        "Invalid URL",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.isLoading {
                    // Loading state
                    ZStack {
                        AnimatedGradientBackground()
                        ProgressView("Loading...")
                    }
                } else if let id = itemId, viewModel.item != nil {
                    // Show item detail using shared view
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
                } else if let error = viewModel.error {
                    // Show fetch error
                    ContentUnavailableView(
                        "Error Loading Item",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                } else if itemId == nil {
                    // Waiting for URL
                    ProgressView("Waiting for URL...")
                } else {
                    // Loading state while fetching
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
    }

    // MARK: - Sign In View

    private var signInView: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 80)

                AnimatedSecurityIcon(style: .lock)

                Spacer()
                    .frame(height: 24)

                // Title with animation
                Text("Sign In Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .opacity(showSignInTitle ? 1 : 0)
                    .offset(y: showSignInTitle ? 0 : 15)

                Spacer()
                    .frame(height: 12)

                // Description
                Text("This item is private. Please sign in to view it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showSignInTitle ? 1 : 0)
                    .offset(y: showSignInTitle ? 0 : 10)

                Spacer()

                // Error and button section
                VStack(spacing: 16) {
                    AuthErrorBanner(message: authError)
                        .padding(.horizontal, 32)

                    PrimaryAuthButton(
                        "Sign In with RxLab",
                        isLoading: isAuthenticating
                    ) {
                        Task {
                            await signIn()
                        }
                    }
                    .padding(.horizontal, 90)
                    .opacity(showSignInButton ? 1 : 0)
                    .scaleEffect(showSignInButton ? 1 : 0.95)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            triggerSignInAnimations()
        }
    }

    private func triggerSignInAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showSignInTitle = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            showSignInButton = true
        }
    }

    // MARK: - Access Denied View

    private var accessDeniedView: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 80)

                AnimatedSecurityIcon(style: .denied)

                Spacer()
                    .frame(height: 24)

                // Title with animation
                Text("Access Denied")
                    .font(.title2)
                    .fontWeight(.bold)
                    .opacity(showDeniedTitle ? 1 : 0)
                    .offset(y: showDeniedTitle ? 0 : 15)

                Spacer()
                    .frame(height: 12)

                // Description
                Text("You don't have permission to view this item. Contact the owner to request access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showDeniedTitle ? 1 : 0)
                    .offset(y: showDeniedTitle ? 0 : 10)

                Spacer()
                    .frame(height: 24)

                // Signed in as indicator
                if let user = oauthManager.currentUser, let email = user.email {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                        Text("Signed in as \(email)")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .opacity(showDeniedTitle ? 1 : 0)
                }

                Spacer()

                // Try different account button
                SecondaryAuthButton(
                    "Try Different Account",
                    icon: "arrow.triangle.2.circlepath"
                ) {
                    showTryDifferentAccountConfirmation = true
                }
                .opacity(showDeniedButton ? 1 : 0)
                .confirmationDialog(
                    title: "Sign Out",
                    message: "Are you sure you want to sign out and try a different account?",
                    confirmButtonTitle: "Sign Out",
                    isPresented: $showTryDifferentAccountConfirmation
                ) {
                    Task {
                        await tryDifferentAccount()
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            triggerDeniedAnimations()
        }
    }

    private func triggerDeniedAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showDeniedTitle = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            showDeniedButton = true
        }
    }

    private func tryDifferentAccount() async {
        // Clear tokens and sign out
        try? await TokenStorage.shared.clearAll()
        await oauthManager.logout()

        // Reset animation states
        showSignInTitle = false
        showSignInButton = false
        showDeniedTitle = false
        showDeniedButton = false

        // Retry fetching the item (will show sign-in view again)
        if let id = itemId {
            await fetchItem(id)
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
            // Start fetching the item
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
                // Private item - need to sign in
                needsAuth = true
            case .forbidden:
                // Signed in but not whitelisted
                accessDenied = true
            default:
                break
            }
        }
    }

    // MARK: - Sign In

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
}

#Preview {
    AppClipRootView()
}
