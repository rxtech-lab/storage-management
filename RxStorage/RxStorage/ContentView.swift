//
//  ContentView.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/27/26.
//

import RxStorageCore
import SwiftUI

struct ContentView: View {
    var authManager: OAuthManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                AuthLoadingView()
            case .authenticated:
                AdaptiveRootView()
            case .unauthenticated:
                RxSignInView(
                    manager: authManager,
                    appearance: RxSignInAppearance(
                        icon: .systemImage("shippingbox.circle.fill"),
                        title: "RxStorage",
                        subtitle: "Storage Management System",
                        signInButtonTitle: "Sign In with OAuth"
                    )
                )
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

// MARK: - Previews

#Preview {
    ContentView(authManager: OAuthManager(configuration: AppConfiguration.shared.rxAuthConfiguration))
}

#Preview("Auth Loading") {
    AuthLoadingView()
}
