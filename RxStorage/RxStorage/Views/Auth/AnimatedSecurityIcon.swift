//
//  AnimatedSecurityIcon.swift
//  RxStorage
//
//  Modern animated security icons with glassmorphism for authentication states
//

import SwiftUI

enum SecurityIconStyle {
    case lock // For "Sign In Required" - orange/amber, pulsing
    case denied // For "Access Denied" - red, shake on appear
}

struct AnimatedSecurityIcon: View {
    let style: SecurityIconStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPulsing = false
    @State private var shakeOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var glowPulse = false

    private var iconName: String {
        switch style {
        case .lock:
            return "lock.shield.fill"
        case .denied:
            return "hand.raised.fill"
        }
    }

    private var primaryColor: Color {
        switch style {
        case .lock:
            return .orange
        case .denied:
            return .red
        }
    }

    private var secondaryColor: Color {
        switch style {
        case .lock:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Amber
        case .denied:
            return Color(red: 1.0, green: 0.3, blue: 0.4) // Pink-red
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    var body: some View {
        ZStack {
            // Glow effect behind the glass card
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(glowPulse ? 0.4 : 0.25),
                            secondaryColor.opacity(glowPulse ? 0.2 : 0.1),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 150, height: 150)
                .blur(radius: 25)

            // Glass card
            glassBackground
                .frame(width: 120, height: 120)
                .shadow(
                    color: primaryColor.opacity(colorScheme == .dark ? 0.3 : 0.2),
                    radius: glowPulse ? 20 : 12,
                    x: 0,
                    y: 8
                )

            // Main icon
            Image(systemName: iconName)
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            primaryColor,
                            secondaryColor,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: primaryColor.opacity(0.4),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isPulsing && style == .lock && !reduceMotion ? 1.05 : 1.0)
        }
        .offset(x: shakeOffset)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.7)
        .offset(y: isVisible ? 0 : 25)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                isVisible = true
            }

            guard !reduceMotion else { return }

            // Style-specific animations
            switch style {
            case .lock:
                // Start pulsing and glow after entrance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(
                        .easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }

                    withAnimation(
                        .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        glowPulse = true
                    }
                }

            case .denied:
                // Shake animation on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    triggerShake()
                }
            }
        }
        .accessibilityLabel(style == .lock ? "Lock icon" : "Access denied icon")
    }

    private func triggerShake() {
        withAnimation(.default) {
            shakeOffset = 15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 10)) {
                shakeOffset = 0
            }
        }
    }
}

#Preview("Lock - Light") {
    ZStack {
        AnimatedGradientBackground()
        AnimatedSecurityIcon(style: .lock)
    }
    .preferredColorScheme(.light)
}

#Preview("Lock - Dark") {
    ZStack {
        AnimatedGradientBackground()
        AnimatedSecurityIcon(style: .lock)
    }
    .preferredColorScheme(.dark)
}

#Preview("Denied") {
    ZStack {
        AnimatedGradientBackground()
        AnimatedSecurityIcon(style: .denied)
    }
}
