//
//  AccountDeletionViewModel.swift
//  RxStorageCore
//
//  View model for account deletion functionality
//

import Foundation

/// View model for account deletion operations
@Observable
@MainActor
public final class AccountDeletionViewModel {
    /// Whether the account has a pending deletion
    public private(set) var isPendingDeletion: Bool = false

    /// The pending deletion record
    public private(set) var pendingDeletion: AccountDeletion?

    /// Loading state
    public private(set) var isLoading: Bool = false

    /// Error state
    public private(set) var error: Error?

    private let service: AccountDeletionServiceProtocol

    public init(service: AccountDeletionServiceProtocol = AccountDeletionService()) {
        self.service = service
    }

    /// Fetch the current account deletion status
    public func fetchStatus() async {
        isLoading = true
        error = nil
        do {
            let status = try await service.getStatus()
            isPendingDeletion = status.pending
            pendingDeletion = status.deletion?.value1
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Request account deletion
    public func requestDeletion() async {
        isLoading = true
        error = nil
        do {
            let response = try await service.requestDeletion()
            isPendingDeletion = true
            pendingDeletion = response.deletion.value1
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Cancel pending account deletion
    public func cancelDeletion() async {
        isLoading = true
        error = nil
        do {
            try await service.cancelDeletion()
            isPendingDeletion = false
            pendingDeletion = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Clear error state
    public func clearError() {
        error = nil
    }
}
