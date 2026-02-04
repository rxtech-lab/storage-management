//
//  ErrorViewModelProtocol.swift
//  RxStorageCore
//
//  Protocol for centralized error display view model
//

import Foundation

/// Protocol for error display view model operations
@MainActor
public protocol ErrorViewModelProtocol: AnyObject, Observable {
    /// The current error to display
    var error: Error? { get }

    /// Whether the error alert is presented
    var isPresented: Bool { get set }

    /// Show an error in the UI
    /// - Parameter error: The error to display
    func showError(_ error: Error)

    /// Clear the current error
    func clearError()
}
