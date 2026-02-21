//
//  MockNFCWriter.swift
//  RxStorageCoreTests
//
//  Mock NFC writer for testing
//

import Foundation
@testable import RxStorageCore

#if canImport(CoreNFC)

    /// Mock NFC writer for testing
    @MainActor
    public final class MockNFCWriter: NFCWriterProtocol, @unchecked Sendable {
        // MARK: - Properties

        public var writeResult: Result<Void, Error> = .success(())
        public var writeCalled = false
        public var lastWrittenUrl: String?
        public var lastAllowOverwrite: Bool?
        public var delay: Duration?

        public var lockResult: Result<Void, Error> = .success(())
        public var lockCalled = false

        // MARK: - Initialization

        public init() {}

        // MARK: - NFCWriterProtocol

        public func writeToNfcChip(url: String, allowOverwrite: Bool) async throws {
            writeCalled = true
            lastWrittenUrl = url
            lastAllowOverwrite = allowOverwrite

            if let delay = delay {
                try await Task.sleep(for: delay)
            }

            switch writeResult {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }

        public func lockNfcTag() async throws {
            lockCalled = true

            switch lockResult {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }
    }

#endif
