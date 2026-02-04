//
//  QrCodeScanResponse.swift
//  RxStorageCore
//
//  Response model for QR code scan API endpoint
//

import Foundation

// MARK: - QR Code Scan Response

/// Response from the QR code scan endpoint
public struct QrCodeScanResponse: Codable, Sendable {
    /// Type of resource found (e.g., "item")
    public let type: String

    /// Full API URL to the resource
    public let url: String

    public init(type: String, url: String) {
        self.type = type
        self.url = url
    }
}

// MARK: - QR Code Scan Request

/// Request body for QR code scan endpoint
public struct QrCodeScanRequest: Codable, Sendable {
    /// QR code content to scan
    public let qrcontent: String

    public init(qrcontent: String) {
        self.qrcontent = qrcontent
    }
}
