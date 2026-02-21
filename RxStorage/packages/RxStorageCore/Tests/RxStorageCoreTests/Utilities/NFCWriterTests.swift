//
//  NFCWriterTests.swift
//  RxStorageCoreTests
//
//  Tests for NFCWriter and NFCWriterError
//

import Foundation
@testable import RxStorageCore
import Testing

#if canImport(CoreNFC)

    @Suite("NFCWriterError Tests")
    struct NFCWriterErrorTests {
        // MARK: - Error Description Tests

        @Test("notAvailable error has correct description")
        func notAvailableErrorDescription() {
            let error = NFCWriterError.notAvailable
            #expect(error.errorDescription == "NFC is not available on this device")
        }

        @Test("noTag error has correct description")
        func noTagErrorDescription() {
            let error = NFCWriterError.noTag
            #expect(error.errorDescription == "No NFC tag was detected")
        }

        @Test("notWritable error has correct description")
        func notWritableErrorDescription() {
            let error = NFCWriterError.notWritable
            #expect(error.errorDescription == "This NFC tag is not writable")
        }

        @Test("invalidURL error has correct description")
        func invalidURLErrorDescription() {
            let error = NFCWriterError.invalidURL
            #expect(error.errorDescription == "Invalid URL format")
        }

        @Test("cancelled error has correct description")
        func cancelledErrorDescription() {
            let error = NFCWriterError.cancelled
            #expect(error.errorDescription == "NFC operation was cancelled")
        }

        @Test("writeFailed error includes message in description")
        func writeFailedErrorDescription() {
            let message = "Connection lost"
            let error = NFCWriterError.writeFailed(message)
            #expect(error.errorDescription?.contains(message) == true)
        }

        // MARK: - Error Equality Tests

        @Test("cancelled errors are equal")
        func cancelledEquality() {
            let error1 = NFCWriterError.cancelled
            let error2 = NFCWriterError.cancelled
            #expect(error1 == error2)
        }

        @Test("writeFailed errors with same message are equal")
        func writeFailedEquality() {
            let error1 = NFCWriterError.writeFailed("test")
            let error2 = NFCWriterError.writeFailed("test")
            #expect(error1 == error2)
        }

        @Test("writeFailed errors with different messages are not equal")
        func writeFailedInequality() {
            let error1 = NFCWriterError.writeFailed("test1")
            let error2 = NFCWriterError.writeFailed("test2")
            #expect(error1 != error2)
        }

        // MARK: - New Error Case Tests

        @Test("tagHasExistingContent error has correct description")
        func tagHasExistingContentErrorDescription() {
            let error = NFCWriterError.tagHasExistingContent("https://example.com")
            #expect(error.errorDescription?.contains("https://example.com") == true)
            #expect(error.errorDescription?.contains("already has content") == true)
        }

        @Test("lockFailed error has correct description")
        func lockFailedErrorDescription() {
            let error = NFCWriterError.lockFailed("Connection lost")
            #expect(error.errorDescription?.contains("Connection lost") == true)
            #expect(error.errorDescription?.contains("lock") == true)
        }

        @Test("tagHasExistingContent errors with same content are equal")
        func tagHasExistingContentEquality() {
            let error1 = NFCWriterError.tagHasExistingContent("test")
            let error2 = NFCWriterError.tagHasExistingContent("test")
            #expect(error1 == error2)
        }

        @Test("tagHasExistingContent errors with different content are not equal")
        func tagHasExistingContentInequality() {
            let error1 = NFCWriterError.tagHasExistingContent("test1")
            let error2 = NFCWriterError.tagHasExistingContent("test2")
            #expect(error1 != error2)
        }

        @Test("lockFailed errors with same message are equal")
        func lockFailedEquality() {
            let error1 = NFCWriterError.lockFailed("test")
            let error2 = NFCWriterError.lockFailed("test")
            #expect(error1 == error2)
        }
    }

    @Suite("MockNFCWriter Tests")
    struct MockNFCWriterTests {
        @Test("MockNFCWriter tracks write calls")
        @MainActor
        func writeCallTracking() async throws {
            let mock = MockNFCWriter()
            #expect(mock.writeCalled == false)

            try await mock.writeToNfcChip(url: "https://example.com")

            #expect(mock.writeCalled == true)
            #expect(mock.lastWrittenUrl == "https://example.com")
            #expect(mock.lastAllowOverwrite == false)
        }

        @Test("MockNFCWriter tracks allowOverwrite parameter")
        @MainActor
        func writeWithOverwriteTracking() async throws {
            let mock = MockNFCWriter()

            try await mock.writeToNfcChip(url: "https://example.com", allowOverwrite: true)

            #expect(mock.writeCalled == true)
            #expect(mock.lastAllowOverwrite == true)
        }

        @Test("MockNFCWriter returns success by default")
        @MainActor
        func defaultSuccess() async throws {
            let mock = MockNFCWriter()

            // Should not throw
            try await mock.writeToNfcChip(url: "https://example.com")
        }

        @Test("MockNFCWriter throws configured error")
        @MainActor
        func configuredError() async throws {
            let mock = MockNFCWriter()
            mock.writeResult = .failure(NFCWriterError.cancelled)

            await #expect(throws: NFCWriterError.cancelled) {
                try await mock.writeToNfcChip(url: "https://example.com")
            }
        }

        @Test("MockNFCWriter can simulate cancellation")
        @MainActor
        func cancellationSimulation() async throws {
            let mock = MockNFCWriter()
            mock.writeResult = .failure(NFCWriterError.cancelled)

            do {
                try await mock.writeToNfcChip(url: "https://example.com")
                Issue.record("Expected error to be thrown")
            } catch let error as NFCWriterError {
                #expect(error == .cancelled)
            }
        }

        @Test("MockNFCWriter tracks lock calls")
        @MainActor
        func lockCallTracking() async throws {
            let mock = MockNFCWriter()
            #expect(mock.lockCalled == false)

            try await mock.lockNfcTag()

            #expect(mock.lockCalled == true)
        }

        @Test("MockNFCWriter lock throws configured error")
        @MainActor
        func lockConfiguredError() async throws {
            let mock = MockNFCWriter()
            mock.lockResult = .failure(NFCWriterError.lockFailed("test"))

            await #expect(throws: NFCWriterError.lockFailed("test")) {
                try await mock.lockNfcTag()
            }
        }

        @Test("MockNFCWriter can simulate tagHasExistingContent")
        @MainActor
        func existingContentSimulation() async throws {
            let mock = MockNFCWriter()
            mock.writeResult = .failure(NFCWriterError.tagHasExistingContent("https://old.com"))

            do {
                try await mock.writeToNfcChip(url: "https://example.com")
                Issue.record("Expected error to be thrown")
            } catch let error as NFCWriterError {
                #expect(error == .tagHasExistingContent("https://old.com"))
            }
        }
    }

#endif
