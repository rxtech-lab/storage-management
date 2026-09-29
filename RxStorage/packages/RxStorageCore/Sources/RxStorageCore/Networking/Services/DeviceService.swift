//
//  DeviceService.swift
//  RxStorageCore
//
//  Device service for registering APNs tokens for push notifications
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "DeviceService")

// MARK: - Protocol

/// Protocol for push notification device registration
public protocol DeviceServiceProtocol: Sendable {
    func registerDevice(_ request: DeviceRegisterRequest) async throws -> Device
    func unregisterDevice(token: String) async throws
}

// MARK: - Implementation

/// Device service implementation using generated OpenAPI client
public struct DeviceService: DeviceServiceProtocol {
    public init() {}

    @APICall(.created)
    public func registerDevice(_ request: DeviceRegisterRequest) async throws -> Device {
        try await StorageAPIClient.shared.client.registerDevice(.init(body: .json(request)))
    }

    public func unregisterDevice(token: String) async throws {
        let response = try await StorageAPIClient.shared.client.unregisterDevice(.init(path: .init(token: token)))

        switch response {
        case .ok:
            return
        case let .badRequest(badRequest):
            let error = try? badRequest.body.json
            throw APIError.badRequest(error?.error ?? "Invalid request")
        case .unauthorized:
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.forbidden
        case .notFound:
            throw APIError.notFound
        case .internalServerError:
            throw APIError.serverError("Internal server error")
        case let .undocumented(statusCode, _):
            throw APIError.serverError("HTTP \(statusCode)")
        }
    }
}
