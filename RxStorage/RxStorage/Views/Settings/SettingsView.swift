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
    private var authManager = OAuthManager.shared
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
                                case .success(let image):
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
                Link(destination: URL(string: "https://storage.rxlab.app/support")!) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }

                Link(destination: URL(string: "https://storage.rxlab.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://storage.rxlab.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
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
            "Sign Out",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    private func signOut() async {
        try? await TokenStorage.shared.clearAll()
        await authManager.logout()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
