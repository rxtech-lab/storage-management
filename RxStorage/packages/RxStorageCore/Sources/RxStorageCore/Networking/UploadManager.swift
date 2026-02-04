//
//  UploadManager.swift
//  RxStorageCore
//
//  Manages file uploads to S3 with progress tracking and cancellation
//

import Foundation
import Logging
import OpenAPIRuntime

/// Progress callback type: (uploadedBytes, totalBytes)
public typealias UploadProgressHandler = @Sendable (Int64, Int64) -> Void

/// Manages file uploads with progress tracking and cancellation support
public actor UploadManager: NSObject {
    /// Shared singleton instance
    public static let shared = UploadManager()

    private let logger = Logger(label: "com.rxlab.rxstorage.UploadManager")

    /// Active upload tasks keyed by URLSession task identifier
    private var activeTasks: [Int: UploadTaskInfo] = [:]

    /// URLSession for uploads with delegate
    private lazy var uploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 600 // 10 minutes
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Internal tracking for active uploads
    private struct UploadTaskInfo {
        let uploadId: UUID
        let progressHandler: UploadProgressHandler?
        let continuation: CheckedContinuation<UploadResult, Error>
        let presignedResponse: PresignedUploadResponse
        var urlSessionTask: URLSessionUploadTask?
    }

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public API

    /// Upload a file to S3
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - onProgress: Optional progress callback (uploadedBytes, totalBytes)
    /// - Returns: UploadResult with the fileId and publicUrl
    /// - Throws: UploadError if upload fails
    public func upload(
        file fileURL: URL,
        onProgress: UploadProgressHandler? = nil
    ) async throws -> UploadResult {
        // 1. Validate file exists and get metadata
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadError.fileNotFound
        }

        let filename = fileURL.lastPathComponent
        let contentType = MIMEType.from(url: fileURL)

        // Only allow images
        guard MIMEType.isImage(contentType) else {
            throw UploadError.invalidContentType
        }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        logger.info("Starting upload", metadata: [
            "filename": "\(filename)",
            "contentType": "\(contentType)",
            "size": "\(fileSize)",
        ])

        // 2. Get presigned URL from backend using generated client
        let presignedResponse: PresignedUploadResponse
        do {
            let client = StorageAPIClient.shared.client
            let request = PresignedUploadRequest(
                filename: filename,
                contentType: contentType,
                size: Int(fileSize)
            )
            let response = try await client.getPresignedUploadUrl(.init(body: .json(request)))
            switch response {
            case let .created(createdResponse):
                presignedResponse = try createdResponse.body.json
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
        } catch let error as APIError {
            logger.error("Failed to get presigned URL", metadata: ["error": "\(error)"])
            throw UploadError.presignedURLFailed(error.localizedDescription)
        } catch {
            logger.error("Failed to get presigned URL", metadata: ["error": "\(error)"])
            throw UploadError.presignedURLFailed(error.localizedDescription)
        }

        logger.info("Got presigned URL", metadata: [
            "fileId": "\(presignedResponse.fileId)",
            "key": "\(presignedResponse.key)",
        ])

        // 3. Upload to S3 with progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.performUpload(
                    fileURL: fileURL,
                    presignedResponse: presignedResponse,
                    contentType: contentType,
                    progressHandler: onProgress,
                    continuation: continuation
                )
            }
        }
    }

    /// Cancel an active upload by its upload ID
    /// - Parameter uploadId: The UUID of the upload to cancel
    public func cancel(uploadId: UUID) {
        for (taskId, info) in activeTasks {
            if info.uploadId == uploadId {
                info.urlSessionTask?.cancel()
                activeTasks.removeValue(forKey: taskId)
                info.continuation.resume(throwing: UploadError.cancelled)
                logger.info("Upload cancelled", metadata: ["uploadId": "\(uploadId)"])
                break
            }
        }
    }

    /// Cancel all active uploads
    public func cancelAll() {
        for (_, info) in activeTasks {
            info.urlSessionTask?.cancel()
            info.continuation.resume(throwing: UploadError.cancelled)
        }
        activeTasks.removeAll()
        logger.info("All uploads cancelled")
    }

    // MARK: - Private Methods

    private func performUpload(
        fileURL: URL,
        presignedResponse: PresignedUploadResponse,
        contentType: String,
        progressHandler: UploadProgressHandler?,
        continuation: CheckedContinuation<UploadResult, Error>
    ) {
        guard let uploadURL = URL(string: presignedResponse.uploadUrl) else {
            continuation.resume(throwing: UploadError.invalidFileURL)
            return
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let uploadTask = uploadSession.uploadTask(with: request, fromFile: fileURL)
        let uploadId = UUID()

        var taskInfo = UploadTaskInfo(
            uploadId: uploadId,
            progressHandler: progressHandler,
            continuation: continuation,
            presignedResponse: presignedResponse
        )
        taskInfo.urlSessionTask = uploadTask

        activeTasks[uploadTask.taskIdentifier] = taskInfo
        uploadTask.resume()

        logger.info("Upload task started", metadata: [
            "uploadId": "\(uploadId)",
            "taskIdentifier": "\(uploadTask.taskIdentifier)",
        ])
    }
}

// MARK: - URLSessionTaskDelegate

extension UploadManager: URLSessionTaskDelegate {
    /// Called when upload progress is made
    public nonisolated func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        Task {
            await self.handleProgress(
                taskIdentifier: task.taskIdentifier,
                bytesSent: totalBytesSent,
                totalBytes: totalBytesExpectedToSend
            )
        }
    }

    /// Called when task completes (success or failure)
    public nonisolated func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task {
            await self.handleCompletion(
                taskIdentifier: task.taskIdentifier,
                response: task.response,
                error: error
            )
        }
    }

    // MARK: - Private Delegate Handlers

    private func handleProgress(
        taskIdentifier: Int,
        bytesSent: Int64,
        totalBytes: Int64
    ) {
        guard let taskInfo = activeTasks[taskIdentifier] else { return }
        taskInfo.progressHandler?(bytesSent, totalBytes)
    }

    private func handleCompletion(
        taskIdentifier: Int,
        response: URLResponse?,
        error: Error?
    ) {
        guard let taskInfo = activeTasks.removeValue(forKey: taskIdentifier) else { return }

        // Handle cancellation
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                // Cancellation is handled in cancel() method
                logger.info("Upload task was cancelled", metadata: [
                    "taskIdentifier": "\(taskIdentifier)",
                ])
                return
            }
            logger.error("Upload failed with error", metadata: [
                "error": "\(error)",
                "taskIdentifier": "\(taskIdentifier)",
            ])
            taskInfo.continuation.resume(throwing: UploadError.uploadFailed(error.localizedDescription))
            return
        }

        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode >= 200, httpResponse.statusCode < 300 {
                let result = UploadResult(
                    fileId: taskInfo.presignedResponse.fileId,
                    publicUrl: taskInfo.presignedResponse.publicUrl,
                    key: taskInfo.presignedResponse.key
                )
                logger.info("Upload completed successfully", metadata: [
                    "fileId": "\(result.fileId)",
                    "publicUrl": "\(result.publicUrl)",
                ])
                taskInfo.continuation.resume(returning: result)
            } else {
                logger.error("Upload failed with status", metadata: [
                    "status": "\(httpResponse.statusCode)",
                    "taskIdentifier": "\(taskIdentifier)",
                ])
                taskInfo.continuation.resume(
                    throwing: UploadError.uploadFailed("HTTP \(httpResponse.statusCode)")
                )
            }
        } else {
            taskInfo.continuation.resume(
                throwing: UploadError.uploadFailed("Invalid response")
            )
        }
    }
}
