//
//  ErrorAlertModifier.swift
//  RxStorageCore
//
//  View modifier for displaying errors from ErrorViewModel
//

import SwiftUI

extension View {
    /// Add an error alert that displays errors from the given ErrorViewModel
    /// - Parameter errorViewModel: The error view model to observe
    /// - Returns: A view with the error alert modifier applied
    public func showViewModelError(_ errorViewModel: ErrorViewModel) -> some View {
        self.alert("Error", isPresented: Bindable(errorViewModel).isPresented) {
            Button("OK") {
                errorViewModel.clearError()
            }
        } message: {
            if let error = errorViewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}
