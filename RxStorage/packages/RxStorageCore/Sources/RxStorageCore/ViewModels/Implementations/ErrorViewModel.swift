//
//  ErrorViewModel.swift
//  RxStorageCore
//
//  Centralized error display view model for showing errors in the UI
//

import Foundation

/// View model for centralized error display
@Observable
@MainActor
public final class ErrorViewModel: ErrorViewModelProtocol {
    /// The current error to display
    public private(set) var error: Error?

    /// Whether the error alert is presented
    public var isPresented: Bool = false

    public init() {}

    /// Show an error in the UI
    /// - Parameter error: The error to display
    public func showError(_ error: Error) {
        self.error = error
        isPresented = true
    }

    /// Clear the current error
    public func clearError() {
        error = nil
        isPresented = false
    }
}
