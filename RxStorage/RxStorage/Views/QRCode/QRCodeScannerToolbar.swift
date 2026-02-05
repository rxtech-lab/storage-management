//
//  QRCodeScannerToolbar.swift
//  RxStorage
//
//  Reusable QR code scanner toolbar button (iOS only)
//

import SwiftUI

#if os(iOS)

    /// View modifier that adds a QR code scanner toolbar button
    struct QRCodeScannerToolbarModifier: ViewModifier {
        @Binding var isPresented: Bool

        func body(content: Content) -> some View {
            content
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPresented = true
                        } label: {
                            Label("Scan", systemImage: "qrcode.viewfinder")
                        }
                        .accessibilityIdentifier("qr-scanner-button")
                    }
                }
        }
    }

    extension View {
        /// Adds a QR code scanner toolbar button (iOS only)
        func qrCodeScannerToolbar(isPresented: Binding<Bool>) -> some View {
            modifier(QRCodeScannerToolbarModifier(isPresented: isPresented))
        }
    }

#endif
