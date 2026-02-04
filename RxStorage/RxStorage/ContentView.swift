//
//  ContentView.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/27/26.
//

import RxStorageCore
import SwiftUI

struct ContentView: View {
    private var authManager = OAuthManager.shared

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                AuthLoadingView()
            case .authenticated:
                AdaptiveRootView()
            case .unauthenticated:
                LoginView()
                #if os(macOS)
                    .frame(maxWidth: 500, maxHeight: 700)
                #endif
            }
        }
    }
}

// MARK: - Auth Loading View

/// Loading view shown while checking authentication status
private struct AuthLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    @State private var ringScales: [CGFloat] = [1.0, 1.0, 1.0]

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 32) {
                ZStack {
                    // Concentric pulsing rings
                    ForEach(0 ..< 3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.blue.opacity(0.3 - Double(index) * 0.08),
                                lineWidth: 2
                            )
                            .frame(
                                width: 80 + CGFloat(index) * 30,
                                height: 80 + CGFloat(index) * 30
                            )
                            .scaleEffect(ringScales[index])
                            .opacity(reduceMotion ? 0.5 : (isAnimating ? 0 : 0.8))
                    }

                    // Inner circle background
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)

                    // Key icon with rotation
                    Image(systemName: "key.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (isAnimating ? 360 : 0)))
                }

                VStack(spacing: 8) {
                    Text("Authenticating")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("Please wait")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LoadingDots()
                    }
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }

            // Staggered ring animations
            for index in 0 ..< 3 {
                withAnimation(
                    .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3)
                ) {
                    ringScales[index] = 1.0 + CGFloat(index) * 0.15
                }
            }

            // Rotation animation
            withAnimation(
                .linear(duration: 8)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }
}

// MARK: - Loading Dots

/// Animated loading dots
private struct LoadingDots: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(index < dotCount ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

// MARK: - Login View

/// Modern login screen with animations
struct LoginView: View {
    private var authManager = OAuthManager.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    // Animation states
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Animated logo
                AnimatedAppLogo()

                Spacer()
                    .frame(height: 24)

                // Title with entrance animation
                Text("RxStorage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 15)

                Spacer()
                    .frame(height: 8)

                // Subtitle with entrance animation
                Text("Storage Management System")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 10)

                Spacer()

                // Error and button section
                VStack(spacing: 16) {
                    AuthErrorBanner(message: errorMessage)
                        .padding(.horizontal, 32)

                    PrimaryAuthButton(
                        "Sign In with OAuth",
                        isLoading: isAuthenticating
                    ) {
                        Task {
                            await signIn()
                        }
                    }
                    .padding(.horizontal, 90)
                    .opacity(showButton ? 1 : 0)
                    .scaleEffect(showButton ? 1 : 0.95)
                }

                Spacer()
                    .frame(height: 20)

                // Trust indicator
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("Secured by RxLab")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
                .opacity(showButton ? 1 : 0)

                Spacer()
                    .frame(height: 32)
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
        .onAppear {
            triggerEntranceAnimations()
        }
    }

    private func triggerEntranceAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showTitle = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
            showSubtitle = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            showButton = true
        }
    }

    private func signIn() async {
        isAuthenticating = true
        errorMessage = nil

        do {
            try await authManager.authenticate()
        } catch {
            errorMessage = error.localizedDescription
        }

        isAuthenticating = false
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}

#Preview("Login") {
    LoginView()
}

#Preview("Auth Loading") {
    AuthLoadingView()
}
