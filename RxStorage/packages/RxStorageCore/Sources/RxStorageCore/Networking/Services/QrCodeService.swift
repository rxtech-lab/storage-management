//
//  QrCodeService.swift
//  RxStorageCore
//
//  QR code service for scanning and resolving QR codes via backend API
//

import Foundation
import Logging

private let logger = Logger(label: "QrCodeService")

// MARK: - Protocol

/// Protocol for QR code service operations
public protocol QrCodeServiceProtocol: Sendable {
    /// Scan QR code content and get the resolved URL
    /// - Parameter qrcontent: The raw QR code content (URL or text)
    /// - Returns: QrCodeScanResponse with type and URL
    func scanQrCode(qrcontent: String) async throws -> QrCodeScanResponse
}

// MARK: - Implementation

/// QR code service implementation using direct HTTP requests
/// Uses optional authentication to support both authenticated users and App Clips
public struct QrCodeService: QrCodeServiceProtocol {
    private let configuration: AppConfiguration
    private let tokenStorage: TokenStorage

    public init(
        configuration: AppConfiguration = .shared,
        tokenStorage: TokenStorage = .shared
    ) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage
    }

    public func scanQrCode(qrcontent: String) async throws -> QrCodeScanResponse {
        // Build URL for the endpoint
        let baseURL = configuration.apiBaseURL
        let endpoint = baseURL + "/api/v1/qrcode/scan"

        guard let url = URL(string: endpoint) else {
            logger.error("Invalid URL for QR code scan endpoint: \(endpoint)")
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if available (optional auth for App Clips)
        if let accessToken = await tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Encode request body
        let requestBody = QrCodeScanRequest(qrcontent: qrcontent)
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.error("Failed to encode QR code scan request: \(error)")
            throw APIError.badRequest("Failed to encode request")
        }

        logger.info("Scanning QR code: \(qrcontent)")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw APIError.invalidResponse
        }

        logger.debug("QR code scan response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            do {
                let scanResponse = try JSONDecoder().decode(QrCodeScanResponse.self, from: data)
                logger.info("QR code resolved to: \(scanResponse.url)")
                return scanResponse
            } catch {
                logger.error("Failed to decode QR code scan response: \(error)")
                throw APIError.decodingError(error)
            }
        case 400:
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(QrCodeErrorResponse.self, from: data) {
                logger.warning("QR code scan failed: \(errorResponse.error)")
                throw APIError.unsupportedQRCode(errorResponse.error)
            }
            throw APIError.badRequest("Invalid QR code")
        case 401:
            logger.warning("QR code scan unauthorized")
            throw APIError.unauthorized
        case 403:
            logger.warning("QR code scan forbidden")
            throw APIError.forbidden
        default:
            logger.error("QR code scan failed with status: \(httpResponse.statusCode)")
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - QR Code Error Response

/// Simple error response structure for QR code API
private struct QrCodeErrorResponse: Decodable {
    let error: String
}
