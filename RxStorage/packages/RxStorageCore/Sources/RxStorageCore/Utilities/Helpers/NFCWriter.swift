//
//  NFCWriter.swift
//  RxStorageCore
//
//  Actor for writing URLs to NFC tags
//

import Foundation

#if canImport(CoreNFC)
import CoreNFC
import Logging

/// Protocol for NFC writing operations - enables testing with mocks
public protocol NFCWriterProtocol: Sendable {
    func writeToNfcChip(url: String) async throws
}

/// Actor that handles NFC tag writing operations
public actor NFCWriter: NFCWriterProtocol {
    public init() {}

    /// Writes a URL to an NFC tag
    /// - Parameter url: The URL string to write to the NFC tag
    /// - Throws: NFCWriterError if writing fails
    public func writeToNfcChip(url: String) async throws {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCWriterError.notAvailable
        }

        guard URL(string: url) != nil else {
            throw NFCWriterError.invalidURL
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = NFCWriterDelegate(url: url, continuation: continuation)
            Task { @MainActor in
                delegate.startSession()
            }
        }
    }
}

/// Internal delegate class for handling CoreNFC callbacks
/// CoreNFC requires delegates to be NSObject subclasses
private final class NFCWriterDelegate: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
    private let urlToWrite: String
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: NFCNDEFReaderSession?
    private let logger = Logger(label: "com.rxlab.rxstorage.NFCWriter")

    /// Strong self-reference to prevent deallocation during NFC session
    /// This is cleared when the session completes
    private var retainedSelf: NFCWriterDelegate?

    init(url: String, continuation: CheckedContinuation<Void, Error>) {
        self.urlToWrite = url
        self.continuation = continuation
        super.init()
        logger.debug("NFCWriterDelegate initialized", metadata: ["url": "\(url)"])
    }

    deinit {
        logger.debug("NFCWriterDelegate deallocated")
    }

    @MainActor
    func startSession() {
        // Retain self to prevent deallocation during NFC session
        retainedSelf = self
        logger.info("Starting NFC session", metadata: ["url": "\(urlToWrite)"])
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag to write."
        session?.begin()
        logger.debug("NFC session began")
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        logger.info("NFC session became active - ready to detect tags")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        logger.info("Detected tags", metadata: ["count": "\(tags.count)"])

        guard let tag = tags.first else {
            logger.warning("No tag in detected array")
            session.alertMessage = "No NFC tag detected."
            session.invalidate(errorMessage: "No NFC tag detected.")
            return
        }

        logger.debug("Connecting to tag")
        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Connection failed", metadata: ["error": "\(error.localizedDescription)"])
                session.alertMessage = "Connection failed."
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            self.logger.debug("Connected, querying NDEF status")
            tag.queryNDEFStatus { status, capacity, error in
                self.logger.info("NDEF status query result", metadata: [
                    "status": "\(status.rawValue)",
                    "capacity": "\(capacity)",
                    "error": "\(error?.localizedDescription ?? "none")"
                ])

                if let error = error {
                    self.logger.error("Failed to query tag", metadata: ["error": "\(error.localizedDescription)"])
                    session.alertMessage = "Failed to query tag."
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }

                switch status {
                case .notSupported:
                    self.logger.warning("Tag is not NDEF compatible")
                    session.alertMessage = "Tag is not NDEF compatible."
                    session.invalidate(errorMessage: "Tag is not NDEF compatible.")

                case .readOnly:
                    self.logger.warning("Tag is read-only")
                    session.alertMessage = "Tag is read-only."
                    session.invalidate(errorMessage: "Tag is read-only.")

                case .readWrite:
                    self.logger.info("Tag is read-write, proceeding to write")
                    self.writeURL(to: tag, session: session)

                @unknown default:
                    self.logger.warning("Unknown tag status", metadata: ["status": "\(status.rawValue)"])
                    session.alertMessage = "Unknown tag status."
                    session.invalidate(errorMessage: "Unknown tag status.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        logger.warning("Session invalidated", metadata: ["error": "\(error.localizedDescription)"])

        if let nfcError = error as? NFCReaderError {
            logger.debug("NFCReaderError details", metadata: ["code": "\(nfcError.code.rawValue)"])
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                logger.info("User cancelled NFC session")
                resumeContinuation(with: .failure(NFCWriterError.cancelled))
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                logger.debug("Session invalidated after first NDEF tag read (unexpected in write mode)")
                resumeContinuation(with: .failure(NFCWriterError.cancelled))
            default:
                logger.error("NFC session failed", metadata: ["code": "\(nfcError.code.rawValue)"])
                resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
            }
        } else {
            logger.error("Non-NFC error during session", metadata: ["error": "\(error)"])
            resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
        }
    }

    // MARK: - Required but unused delegate method

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        logger.debug("didDetectNDEFs called (unexpected in write mode)", metadata: ["messageCount": "\(messages.count)"])
    }

    // MARK: - Private Methods

    private func writeURL(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        logger.info("Preparing to write URL", metadata: ["url": "\(urlToWrite)"])

        guard let url = URL(string: urlToWrite),
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            logger.error("Failed to create NDEF payload - invalid URL")
            session.alertMessage = "Invalid URL format."
            session.invalidate(errorMessage: "Invalid URL format.")
            resumeContinuation(with: .failure(NFCWriterError.invalidURL))
            return
        }

        let message = NFCNDEFMessage(records: [payload])
        logger.debug("NDEF message created", metadata: ["records": "\(message.records.count)"])

        logger.info("Writing NDEF message to tag")
        tag.writeNDEF(message) { [weak self] error in
            if let error = error {
                self?.logger.error("Write failed", metadata: ["error": "\(error.localizedDescription)"])
                session.alertMessage = "Write failed: \(error.localizedDescription)"
                session.invalidate(errorMessage: error.localizedDescription)
                self?.resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
            } else {
                self?.logger.info("Write successful")
                session.alertMessage = "URL written successfully!"
                session.invalidate()
                self?.resumeContinuation(with: .success(()))
            }
        }
    }

    private func resumeContinuation(with result: Result<Void, Error>) {
        guard let continuation = continuation else {
            logger.warning("Attempted to resume continuation but it was already consumed")
            return
        }
        self.continuation = nil

        logger.debug("Resuming continuation", metadata: ["success": "\(result)"])

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }

        // Release self-reference now that the operation is complete
        retainedSelf = nil
    }
}

/// Errors that can occur during NFC writing
public enum NFCWriterError: LocalizedError, Sendable {
    case notAvailable
    case noTag
    case notWritable
    case writeFailed(String)
    case invalidURL
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device"
        case .noTag:
            return "No NFC tag was detected"
        case .notWritable:
            return "This NFC tag is not writable"
        case .writeFailed(let message):
            return "Failed to write to NFC tag: \(message)"
        case .invalidURL:
            return "Invalid URL format"
        case .cancelled:
            return "NFC operation was cancelled"
        }
    }
}

#endif
