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
                    ProgressView("Loading...")
                } else if viewModel.item != nil {
                    // Show item detail when loaded successfully
                    itemDetailContent
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
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Sign In Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This item is private. Please sign in to view it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let authError = authError {
                Text(authError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            Button {
                Task {
                    await signIn()
                }
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Sign In with RxLab")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
        }
        .padding()
    }

    // MARK: - Access Denied View

    private var accessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Access Denied")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                "You don't have permission to view this item. Contact the owner to request access."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if let user = oauthManager.currentUser, let email = user.email {
                Text("Signed in as: \(email)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    // MARK: - Item Detail Content

    private var itemDetailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let item = viewModel.item {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let description = item.description {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            if item.visibility == .public {
                                Label("Public", systemImage: "globe")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundStyle(.green)
                                    .cornerRadius(4)
                            } else {
                                Label("Private", systemImage: "lock.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Divider()

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        if let category = item.category {
                            detailRow(label: "Category", value: category.name, icon: "folder")
                        }

                        if let location = item.location {
                            detailRow(label: "Location", value: location.title, icon: "mappin")
                        }

                        if let author = item.author {
                            detailRow(label: "Author", value: author.name, icon: "person")
                        }

                        if let price = item.price {
                            detailRow(
                                label: "Price", value: String(format: "%.2f", price),
                                icon: "dollarsign.circle")
                        }

                        if !item.images.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Images", systemImage: "photo")
                                    .font(.headline)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(item.images, id: \.self) { imageURL in
                                            AsyncImage(url: URL(string: imageURL)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Children
                    if !viewModel.children.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Child Items", systemImage: "list.bullet.indent")
                                .font(.headline)

                            ForEach(viewModel.children) { child in
                                NavigationLink(value: child) {
                                    ItemRow(item: child)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.item?.title ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task {
                            try? await TokenStorage.shared.clearAll()
                            await oauthManager.logout()
                            // Reset state to show sign-in again
                            if let id = itemId {
                                await fetchItem(id)
                            }
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Label(label, systemImage: icon)
                .font(.headline)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .foregroundStyle(.secondary)

            Spacer()
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
            self.itemId = id
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
