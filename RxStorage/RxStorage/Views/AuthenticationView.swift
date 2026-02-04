//
//  AuthenticationView.swift
//  RxStorage
//
//  OAuth authentication view
//

import RxStorageCore
import SwiftUI

/// Authentication view with OAuth login
struct AuthenticationView: View {
    @State private var oauthManager = OAuthManager()
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            // Logo/Title
            VStack(spacing: 12) {
                Image(systemName: "shippingbox.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("RxStorage")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Storage Management System")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Sign in button
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
                    Text("Sign In with OAuth")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)

            Spacer()
        }
        .padding()
        #if os(macOS)
            .frame(maxWidth: 500)
        #endif
    }

    // MARK: - Actions

    private func signIn() async {
        isAuthenticating = true
        errorMessage = nil

        do {
            try await oauthManager.authenticate()
        } catch {
            errorMessage = error.localizedDescription
        }

        isAuthenticating = false
    }
}

#Preview {
    AuthenticationView()
}
