//
//  ConfirmationDialogModifier.swift
//  RxStorage
//
//  Reusable confirmation dialog modifier for destructive actions
//

import SwiftUI

/// A reusable confirmation dialog modifier that displays as a centered alert
struct ConfirmationDialogModifier: ViewModifier {
    let title: String
    let message: String
    let confirmButtonTitle: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?

    init(
        title: String,
        message: String,
        confirmButtonTitle: String = "Confirm",
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmButtonTitle = confirmButtonTitle
        _isPresented = isPresented
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(confirmButtonTitle, role: .destructive) {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {
                    onCancel?()
                }
            } message: {
                Text(message)
            }
    }
}

extension View {
    /// Adds a confirmation dialog for destructive actions
    /// - Parameters:
    ///   - title: The dialog title (e.g., "Delete Item", "Sign Out")
    ///   - message: The confirmation message
    ///   - confirmButtonTitle: The title for the confirm button (default: "Confirm")
    ///   - isPresented: Binding to control dialog visibility
    ///   - onConfirm: Action to perform when user confirms
    ///   - onCancel: Optional action to perform when user cancels
    func confirmationDialog(
        title: String,
        message: String,
        confirmButtonTitle: String = "Confirm",
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(ConfirmationDialogModifier(
            title: title,
            message: message,
            confirmButtonTitle: confirmButtonTitle,
            isPresented: isPresented,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}
