//
//  PlatformColors.swift
//  RxStorage
//
//  Platform-specific color extensions for cross-platform support
//

import SwiftUI
#if os(macOS)
    import AppKit
#endif

// MARK: - Platform Colors

extension Color {
    static var systemGroupedBackground: Color {
        #if os(iOS)
            Color(UIColor.systemGroupedBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondarySystemGroupedBackground: Color {
        #if os(iOS)
            Color(UIColor.secondarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var systemGray6: Color {
        #if os(iOS)
            Color(UIColor.systemGray6)
        #else
            Color(nsColor: .systemGray)
        #endif
    }
}

// MARK: - Card Style Extension

extension View {
    func cardStyle() -> some View {
        padding(16)
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
