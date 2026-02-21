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
