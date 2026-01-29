//
//  NFCWriter.swift
//  RxStorageCore
//
//  Actor for writing URLs to NFC tags
//

import Foundation

#if canImport(CoreNFC)
import CoreNFC

/// Actor that handles NFC tag writing operations
public actor NFCWriter {
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

    init(url: String, continuation: CheckedContinuation<Void, Error>) {
        self.urlToWrite = url
        self.continuation = continuation
        super.init()
    }

    @MainActor
    func startSession() {
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag to write."
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session is active and ready to detect tags
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.alertMessage = "No NFC tag detected."
            session.invalidate(errorMessage: "No NFC tag detected.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                session.alertMessage = "Connection failed."
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.alertMessage = "Failed to query tag."
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }

                switch status {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compatible."
                    session.invalidate(errorMessage: "Tag is not NDEF compatible.")

                case .readOnly:
                    session.alertMessage = "Tag is read-only."
                    session.invalidate(errorMessage: "Tag is read-only.")

                case .readWrite:
                    self.writeURL(to: tag, session: session)

                @unknown default:
                    session.alertMessage = "Unknown tag status."
                    session.invalidate(errorMessage: "Unknown tag status.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check if the error is user cancellation
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                resumeContinuation(with: .failure(NFCWriterError.cancelled))
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                // This shouldn't happen in write mode, but handle it gracefully
                break
            default:
                resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
            }
        } else {
            resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
        }
    }

    // MARK: - Required but unused delegate method

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used for writing, but required by protocol
    }

    // MARK: - Private Methods

    private func writeURL(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let url = URL(string: urlToWrite),
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            session.alertMessage = "Invalid URL format."
            session.invalidate(errorMessage: "Invalid URL format.")
            resumeContinuation(with: .failure(NFCWriterError.invalidURL))
            return
        }

        let message = NFCNDEFMessage(records: [payload])

        tag.writeNDEF(message) { [weak self] error in
            if let error = error {
                session.alertMessage = "Write failed: \(error.localizedDescription)"
                session.invalidate(errorMessage: error.localizedDescription)
                self?.resumeContinuation(with: .failure(NFCWriterError.writeFailed(error.localizedDescription)))
            } else {
                session.alertMessage = "URL written successfully!"
                session.invalidate()
                self?.resumeContinuation(with: .success(()))
            }
        }
    }

    private func resumeContinuation(with result: Result<Void, Error>) {
        guard let continuation = continuation else { return }
        self.continuation = nil

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
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
