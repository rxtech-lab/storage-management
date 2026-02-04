//
//  AppClipAccessDeniedView.swift
//  RxStorage
//
//  Access denied view for App Clips when user lacks permission
//

import RxStorageCore
import SwiftUI

/// Access denied view displayed when user is authenticated but lacks permission
struct AppClipAccessDeniedView: View {
    let userEmail: String?
    let onTryDifferentAccount: () -> Void

    // Animation states
    @State private var showTitle = false
    @State private var showButton = false

    // Confirmation dialog state
    @State private var showConfirmation = false

    var body: some View {
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
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 15)
                    .padding()

                Spacer()
                    .frame(height: 12)

                // Description
                Text("You don't have permission to view this item. Contact the owner to request access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 10)
                    .padding()
                    .accessibilityIdentifier("app-clips-access-denied")

                Spacer()
                    .frame(height: 24)

                // Signed in as indicator
                if let email = userEmail {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                        Text("Signed in as \(email)")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .opacity(showTitle ? 1 : 0)
                }

                Spacer()

                // Try different account button
                SecondaryAuthButton(
                    "Try Different Account",
                    icon: "arrow.triangle.2.circlepath"
                ) {
                    showConfirmation = true
                }
                .opacity(showButton ? 1 : 0)
                .confirmationDialog(
                    title: "Sign Out",
                    message: "Are you sure you want to sign out and try a different account?",
                    confirmButtonTitle: "Sign Out",
                    isPresented: $showConfirmation
                ) {
                    onTryDifferentAccount()
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

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            showButton = true
        }
    }
}

#Preview {
    AppClipAccessDeniedView(
        userEmail: "user@example.com",
        onTryDifferentAccount: {}
    )
}
