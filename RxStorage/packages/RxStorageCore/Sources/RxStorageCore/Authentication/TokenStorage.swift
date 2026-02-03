//
//  TokenStorage.swift
//  RxStorageCore
//
//  Secure token storage using Keychain
//

import Foundation
import Security

/// Protocol for token storage to enable testing without Keychain access
public protocol TokenStorageProtocol: Actor, Sendable {
    func saveAccessToken(_ token: String) throws
    func getAccessToken() -> String?
    func deleteAccessToken() throws
    func saveRefreshToken(_ token: String) throws
    func getRefreshToken() -> String?
    func deleteRefreshToken() throws
    func saveExpiresAt(_ date: Date) throws
    func getExpiresAt() -> Date?
    func deleteExpiresAt() throws
    func isTokenExpired() -> Bool
    func clearAll() throws
}

/// Secure storage for OAuth tokens using Keychain
public actor TokenStorage: TokenStorageProtocol {
    /// Shared singleton instance
    public static let shared = TokenStorage()

    private let serviceName = "com.rxlab.RxStorage"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let expiresAtKey = "expiresAt"

    private init() {}

    // MARK: - Access Token

    /// Store access token securely in Keychain
    public func saveAccessToken(_ token: String) throws {
        try saveToKeychain(key: accessTokenKey, value: token)
    }

    /// Retrieve access token from Keychain
    public func getAccessToken() -> String? {
        return getFromKeychain(key: accessTokenKey)
    }

    /// Delete access token from Keychain
    public func deleteAccessToken() throws {
        try deleteFromKeychain(key: accessTokenKey)
    }

    // MARK: - Refresh Token

    /// Store refresh token securely in Keychain
    public func saveRefreshToken(_ token: String) throws {
        try saveToKeychain(key: refreshTokenKey, value: token)
    }

    /// Retrieve refresh token from Keychain
    public func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }

    /// Delete refresh token from Keychain
    public func deleteRefreshToken() throws {
        try deleteFromKeychain(key: refreshTokenKey)
    }

    // MARK: - Token Expiration

    /// Store token expiration date
    public func saveExpiresAt(_ date: Date) throws {
        let timestamp = date.timeIntervalSince1970
        try saveToKeychain(key: expiresAtKey, value: String(timestamp))
    }

    /// Retrieve token expiration date
    public func getExpiresAt() -> Date? {
        guard let timestampString = getFromKeychain(key: expiresAtKey),
              let timestamp = TimeInterval(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Delete token expiration date
    public func deleteExpiresAt() throws {
        try deleteFromKeychain(key: expiresAtKey)
    }

    // MARK: - Token Validation

    /// Check if access token is expired
    public func isTokenExpired() -> Bool {
        guard let expiresAt = getExpiresAt() else {
            return true
        }
        // Consider expired if within 10 minutes of expiration (for proactive refresh)
        return Date().addingTimeInterval(600) >= expiresAt
    }

    // MARK: - Clear All

    /// Clear all stored tokens
    public func clearAll() throws {
        try? deleteAccessToken()
        try? deleteRefreshToken()
        try? deleteExpiresAt()
    }

    // MARK: - Private Keychain Helpers

    private func saveToKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Keychain Error

public enum KeychainError: LocalizedError, Sendable {
    case encodingFailed
    case saveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for Keychain"
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}
