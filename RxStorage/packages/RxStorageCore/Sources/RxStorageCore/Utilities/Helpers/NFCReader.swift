//
//  NFCReader.swift
//  RxStorageCore
//
//  Actor for reading URLs from NFC tags
//

import Foundation

#if canImport(CoreNFC)
    import CoreNFC
    import Logging

    /// Protocol for NFC reading operations - enables testing with mocks
    public protocol NFCReaderProtocol: Sendable {
        /// Reads the first URL (or text) record from an NFC tag
        func readNfcChip() async throws -> String
    }

    /// Actor that handles NFC tag reading operations
    public actor NFCReader: NFCReaderProtocol {
        public init() {}

        /// Reads the first URL (or text) record from an NFC tag
        /// - Returns: The tag's content as a string
        /// - Throws: NFCReaderError if reading fails
        public func readNfcChip() async throws -> String {
            guard NFCNDEFReaderSession.readingAvailable else {
                throw NFCTagReaderError.notAvailable
            }

            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                let delegate = NFCReaderDelegate(continuation: continuation)
                Task { @MainActor in
                    delegate.startSession()
                }
            }
        }
    }

    /// Internal delegate class for handling CoreNFC read callbacks
    private final class NFCReaderDelegate: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
        private var continuation: CheckedContinuation<String, Error>?
        private var session: NFCNDEFReaderSession?
        private let logger = Logger(label: "com.rxlab.rxstorage.NFCReader")

        /// Strong self-reference to prevent deallocation during NFC session
        private var retainedSelf: NFCReaderDelegate?

        init(continuation: CheckedContinuation<String, Error>) {
            self.continuation = continuation
            super.init()
        }

        @MainActor
        func startSession() {
            retainedSelf = self
            logger.info("Starting NFC read session")
            session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session?.alertMessage = "Hold your iPhone near an item's NFC tag."
            session?.begin()
        }

        // MARK: - NFCNDEFReaderSessionDelegate

        func readerSessionDidBecomeActive(_: NFCNDEFReaderSession) {
            logger.info("NFC read session became active")
        }

        func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
            let records = messages.flatMap(\.records)
            let content = records.lazy.compactMap { record -> String? in
                if let url = record.wellKnownTypeURIPayload() {
                    return url.absoluteString
                }
                let (text, _) = record.wellKnownTypeTextPayload()
                return text
            }.first

            guard let content, !content.isEmpty else {
                logger.warning("NFC tag has no readable URL or text record")
                session.invalidate(errorMessage: "This tag doesn't contain an item link.")
                resumeContinuation(with: .failure(NFCTagReaderError.noContent))
                return
            }

            logger.info("Read NFC tag", metadata: ["content": "\(content)"])
            session.alertMessage = "Tag read successfully."
            resumeContinuation(with: .success(content))
        }

        func readerSession(_: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Expected after a successful read; continuation already resumed
                    resumeContinuation(with: .failure(NFCTagReaderError.cancelled))
                case .readerSessionInvalidationErrorUserCanceled:
                    resumeContinuation(with: .failure(NFCTagReaderError.cancelled))
                default:
                    logger.error("NFC read session failed", metadata: ["code": "\(nfcError.code.rawValue)"])
                    resumeContinuation(with: .failure(NFCTagReaderError.readFailed(error.localizedDescription)))
                }
            } else {
                resumeContinuation(with: .failure(NFCTagReaderError.readFailed(error.localizedDescription)))
            }
        }

        // MARK: - Private Methods

        private func resumeContinuation(with result: Result<String, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(with: result)
            retainedSelf = nil
        }
    }

    /// Errors that can occur during NFC reading
    public enum NFCTagReaderError: LocalizedError, Sendable, Equatable {
        case notAvailable
        case noContent
        case readFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "NFC is not available on this device"
            case .noContent:
                return "This NFC tag doesn't contain an item link"
            case let .readFailed(message):
                return "Failed to read NFC tag: \(message)"
            case .cancelled:
                return "NFC operation was cancelled"
            }
        }
    }
#endif
