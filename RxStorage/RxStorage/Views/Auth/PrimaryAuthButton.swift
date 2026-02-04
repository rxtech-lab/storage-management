//
//  PrimaryAuthButton.swift
//  RxStorage
//
//  Modern authentication button with gradient and glassmorphism effects
//

import SwiftUI
#if os(iOS)
    import UIKit
#endif

struct PrimaryAuthButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            #if os(iOS)
                if !reduceMotion {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            #endif
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(title)
                        .transition(.opacity)
                }
            }
            .padding(.all, 12)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("sign-in-button")
        .buttonStyle(.glassProminent)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .accessibilityHint("Double tap to sign in")
    }
}

/// Plain button style with press animation (for secondary buttons)
struct PressableButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

/// Secondary button variant with glassmorphism
struct SecondaryAuthButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            #if os(iOS)
                if !reduceMotion {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            #endif
            action()
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.blue)
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(in: .capsule)
        }
        .buttonStyle(PressableButtonStyle(reduceMotion: reduceMotion))
        .disabled(isLoading)
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        VStack(spacing: 20) {
            PrimaryAuthButton("Sign In with OAuth", isLoading: false) {}
            PrimaryAuthButton("Sign In with OAuth", isLoading: true) {}
            SecondaryAuthButton("Try Different Account", icon: "arrow.triangle.2.circlepath") {}
        }
        .padding()
    }
}
