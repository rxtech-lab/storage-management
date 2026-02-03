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
    public var delay: Duration?

    // MARK: - Initialization

    public init() {}

    // MARK: - NFCWriterProtocol

    public func writeToNfcChip(url: String) async throws {
        writeCalled = true
        lastWrittenUrl = url

        if let delay = delay {
            try await Task.sleep(for: delay)
        }

        switch writeResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

#endif
