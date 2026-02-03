//
//  NFCWriterTests.swift
//  RxStorageCoreTests
//
//  Tests for NFCWriter and NFCWriterError
//

import Foundation
import Testing

@testable import RxStorageCore

#if canImport(CoreNFC)

@Suite("NFCWriterError Tests")
struct NFCWriterErrorTests {

    // MARK: - Error Description Tests

    @Test("notAvailable error has correct description")
    func testNotAvailableErrorDescription() {
        let error = NFCWriterError.notAvailable
        #expect(error.errorDescription == "NFC is not available on this device")
    }

    @Test("noTag error has correct description")
    func testNoTagErrorDescription() {
        let error = NFCWriterError.noTag
        #expect(error.errorDescription == "No NFC tag was detected")
    }

    @Test("notWritable error has correct description")
    func testNotWritableErrorDescription() {
        let error = NFCWriterError.notWritable
        #expect(error.errorDescription == "This NFC tag is not writable")
    }

    @Test("invalidURL error has correct description")
    func testInvalidURLErrorDescription() {
        let error = NFCWriterError.invalidURL
        #expect(error.errorDescription == "Invalid URL format")
    }

    @Test("cancelled error has correct description")
    func testCancelledErrorDescription() {
        let error = NFCWriterError.cancelled
        #expect(error.errorDescription == "NFC operation was cancelled")
    }

    @Test("writeFailed error includes message in description")
    func testWriteFailedErrorDescription() {
        let message = "Connection lost"
        let error = NFCWriterError.writeFailed(message)
        #expect(error.errorDescription?.contains(message) == true)
    }

    // MARK: - Error Equality Tests

    @Test("cancelled errors are equal")
    func testCancelledEquality() {
        let error1 = NFCWriterError.cancelled
        let error2 = NFCWriterError.cancelled
        #expect(error1 == error2)
    }

    @Test("writeFailed errors with same message are equal")
    func testWriteFailedEquality() {
        let error1 = NFCWriterError.writeFailed("test")
        let error2 = NFCWriterError.writeFailed("test")
        #expect(error1 == error2)
    }

    @Test("writeFailed errors with different messages are not equal")
    func testWriteFailedInequality() {
        let error1 = NFCWriterError.writeFailed("test1")
        let error2 = NFCWriterError.writeFailed("test2")
        #expect(error1 != error2)
    }
}

@Suite("MockNFCWriter Tests")
struct MockNFCWriterTests {

    @Test("MockNFCWriter tracks write calls")
    @MainActor
    func testWriteCallTracking() async throws {
        let mock = MockNFCWriter()
        #expect(mock.writeCalled == false)

        try await mock.writeToNfcChip(url: "https://example.com")

        #expect(mock.writeCalled == true)
        #expect(mock.lastWrittenUrl == "https://example.com")
    }

    @Test("MockNFCWriter returns success by default")
    @MainActor
    func testDefaultSuccess() async throws {
        let mock = MockNFCWriter()

        // Should not throw
        try await mock.writeToNfcChip(url: "https://example.com")
    }

    @Test("MockNFCWriter throws configured error")
    @MainActor
    func testConfiguredError() async throws {
        let mock = MockNFCWriter()
        mock.writeResult = .failure(NFCWriterError.cancelled)

        await #expect(throws: NFCWriterError.cancelled) {
            try await mock.writeToNfcChip(url: "https://example.com")
        }
    }

    @Test("MockNFCWriter can simulate cancellation")
    @MainActor
    func testCancellationSimulation() async throws {
        let mock = MockNFCWriter()
        mock.writeResult = .failure(NFCWriterError.cancelled)

        do {
            try await mock.writeToNfcChip(url: "https://example.com")
            Issue.record("Expected error to be thrown")
        } catch let error as NFCWriterError {
            #expect(error == .cancelled)
        }
    }
}

#endif
