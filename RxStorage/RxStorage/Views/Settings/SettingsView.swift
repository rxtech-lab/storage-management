//
//  SettingsView.swift
//  RxStorage
//
//  Settings view with user info and sign out
//

import RxStorageCore
import SwiftUI

/// Settings view with account info and sign out
struct SettingsView: View {
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(OAuthManager.self) private var authManager
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingCancelDeletionConfirmation = false
    @State private var showingErrorAlert = false
    @State private var accountDeletionViewModel = AccountDeletionViewModel()

    var body: some View {
        List {
            // User Info Section
            if let user = authManager.currentUser {
                Section("Account") {
                    HStack(spacing: 12) {
                        // Profile image
                        if let imageUrl = user.image, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                @unknown default:
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }

                        // User info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name ?? "User")
                                .font(.headline)
                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // App Info Section
            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(
                        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                            ?? "1.0"
                    )
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Build", systemImage: "hammer")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }

            // Support Section
            Section("Support") {
                Button {
                    navigationManager.settingsNavigationPath.append(WebPage.helpAndSupport)
                } label: {
                    HStack {
                        Label("Help & Support", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    navigationManager.settingsNavigationPath.append(WebPage.privacyPolicy)
                } label: {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    navigationManager.settingsNavigationPath.append(WebPage.termsOfService)
                } label: {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Account Deletion Section
            Section {
                if accountDeletionViewModel.isPendingDeletion {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Account Deletion Pending")
                                .font(.headline)
                        }

                        if let deletion = accountDeletionViewModel.pendingDeletion {
                            Text(
                                "Your account is scheduled for deletion on \(deletion.scheduledAt.formatted(date: .abbreviated, time: .shortened))."
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Text("All your data will be permanently deleted. You can cancel this before the scheduled time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        showingCancelDeletionConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Account Deletion")
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        showingDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("Delete Account")
                        }
                    }
                }
            } footer: {
                if !accountDeletionViewModel.isPendingDeletion {
                    Text("Account deletion will be processed within 24 hours. All your items, categories, locations, and uploaded files will be permanently deleted.")
                }
            }

            // Sign Out Section
            Section {
                Button(role: .destructive) {
                    showingSignOutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            confirmButtonTitle: "Sign Out",
            isPresented: $showingSignOutConfirmation
        ) {
            Task {
                await signOut()
            }
        }
        .confirmationDialog(
            title: "Delete Account",
            message:
            "Are you sure you want to delete your account? Your account will be scheduled for deletion in 24 hours. All your data including items, categories, locations, and uploaded files will be permanently deleted. You can cancel the deletion during the grace period.",
            confirmButtonTitle: "Delete Account",
            isPresented: $showingDeleteAccountConfirmation
        ) {
            Task {
                await accountDeletionViewModel.requestDeletion()
            }
        }
        .confirmationDialog(
            title: "Cancel Deletion",
            message: "Are you sure you want to cancel your account deletion request? Your account and all data will be preserved.",
            confirmButtonTitle: "Keep Account",
            isPresented: $showingCancelDeletionConfirmation
        ) {
            Task {
                await accountDeletionViewModel.cancelDeletion()
            }
        }
        .task {
            await accountDeletionViewModel.fetchStatus()
        }
        .alert(
            "Error",
            isPresented: $showingErrorAlert,
            presenting: accountDeletionViewModel.error
        ) { _ in
            Button("OK") {
                accountDeletionViewModel.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: accountDeletionViewModel.error != nil) { _, hasError in
            if hasError {
                showingErrorAlert = true
            }
        }
    }

    private func signOut() async {
        await authManager.logout()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
