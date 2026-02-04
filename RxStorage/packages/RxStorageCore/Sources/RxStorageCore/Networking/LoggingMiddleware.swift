//
//  LoggingMiddleware.swift
//  RxStorageCore
//
//  Middleware that logs request errors for debugging
//

import Foundation
import HTTPTypes
import Logging
import OpenAPIRuntime

/// Middleware that logs request errors and non-success responses
public actor LoggingMiddleware: ClientMiddleware {
    private let logger: Logger

    public init(label: String = "com.rxlab.rxstorage.APIClient") {
        logger = Logger(label: label)
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        do {
            let (response, responseBody) = try await next(request, body, baseURL)

            // Buffer the response body so we can log it and return a new body
            var returnBody: HTTPBody?
            var bodyPreview = "N/A"

            if let responseBody {
                let (data, preview) = try await bufferBody(responseBody)
                bodyPreview = preview
                returnBody = HTTPBody(data)
            }

            if response.status.code >= 400 {
                // Log error responses
                logger.error(
                    "Request failed",
                    metadata: [
                        "operationID": "\(operationID)",
                        "status": "\(response.status.code)",
                        "path": "\(request.path ?? "")",
                        "method": "\(request.method)",
                        "body": "\(bodyPreview)",
                    ]
                )
            } else {
                // Log successful responses at debug level
                logger.info(
                    "Request succeeded",
                    metadata: [
                        "operationID": "\(operationID)",
                        "status": "\(response.status.code)",
                        "path": "\(request.path ?? "")",
                        "method": "\(request.method)",
                        "body": "\(bodyPreview)",
                    ]
                )
            }

            return (response, returnBody)
        } catch let error as DecodingError {
            // Log parsing/decoding errors with details
            logger.error(
                "Response parsing error",
                metadata: [
                    "operationID": "\(operationID)",
                    "path": "\(request.path ?? "")",
                    "method": "\(request.method)",
                    "error": "\(describeDecodingError(error))",
                ]
            )
            throw error
        } catch {
            logger.error(
                "Request error",
                metadata: [
                    "operationID": "\(operationID)",
                    "path": "\(request.path ?? "")",
                    "method": "\(request.method)",
                    "error": "\(error)",
                ]
            )
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Buffer the entire response body and return both the data and a preview string
    private func bufferBody(_ body: HTTPBody) async throws -> (Data, String) {
        var data = Data()
        for try await chunk in body {
            data.append(contentsOf: chunk)
        }
        let preview = String(data: data.prefix(500), encoding: .utf8) ?? "Unable to decode body"
        return (data, preview)
    }
}
