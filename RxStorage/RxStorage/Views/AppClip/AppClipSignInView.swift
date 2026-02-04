//
//  AppClipSignInView.swift
//  RxStorage
//
//  Sign-in view for App Clips when authentication is required
//

import RxStorageCore
import SwiftUI

/// Sign-in view displayed when an App Clip requires authentication
struct AppClipSignInView: View {
    let authError: String?
    let isAuthenticating: Bool
    let onSignIn: () -> Void

    // Animation states
    @State private var showTitle = false
    @State private var showButton = false

    var body: some View {
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
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 15)
                    .accessibilityIdentifier("app-clips-sign-in-required")

                Spacer()
                    .frame(height: 12)

                // Description
                Text("This item is private. Please sign in to view it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 10)

                Spacer()

                // Error and button section
                VStack(spacing: 16) {
                    AuthErrorBanner(message: authError)
                        .padding(.horizontal, 32)

                    PrimaryAuthButton(
                        "Sign In with RxLab",
                        isLoading: isAuthenticating
                    ) {
                        onSignIn()
                    }
                    .padding(.horizontal, 90)
                    .opacity(showButton ? 1 : 0)
                    .scaleEffect(showButton ? 1 : 0.95)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            triggerAnimations()
        }
    }

    private func triggerAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showTitle = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            showButton = true
        }
    }
}

#Preview {
    AppClipSignInView(
        authError: nil,
        isAuthenticating: false,
        onSignIn: {}
    )
}
