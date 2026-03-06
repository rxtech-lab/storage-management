import Foundation
import Testing
@testable import RxStorageCli

@Suite("FileTokenStorage Tests")
struct FileTokenStorageTests {

    private func makeStorage() -> FileTokenStorage {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rxstorage-test-\(UUID().uuidString)")
        return FileTokenStorage(directory: tempDir)
    }

    @Test("Save and retrieve access token")
    func accessTokenRoundTrip() throws {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        try storage.saveAccessToken("test-access-token")
        let retrieved = storage.getAccessToken()
        #expect(retrieved == "test-access-token")
    }

    @Test("Save and retrieve refresh token")
    func refreshTokenRoundTrip() throws {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        try storage.saveRefreshToken("test-refresh-token")
        let retrieved = storage.getRefreshToken()
        #expect(retrieved == "test-refresh-token")
    }

    @Test("Save and retrieve expiration date")
    func expiresAtRoundTrip() throws {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        let date = Date().addingTimeInterval(3600)
        try storage.saveExpiresAt(date)
        let retrieved = storage.getExpiresAt()
        #expect(retrieved != nil)
        // Allow 1 second tolerance for encoding/decoding
        #expect(abs(retrieved!.timeIntervalSince(date)) < 1)
    }

    @Test("Token is expired when no expiration set")
    func expiredWhenNoExpiry() {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        #expect(storage.isTokenExpired())
    }

    @Test("Token is not expired when expiration is in the future")
    func notExpiredWhenFuture() throws {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        try storage.saveExpiresAt(Date().addingTimeInterval(3600))
        #expect(!storage.isTokenExpired())
    }

    @Test("Token is expired when expiration is within 10 minutes")
    func expiredWithin10Minutes() throws {
        let storage = makeStorage()
        defer { try? storage.clearAll() }

        // 5 minutes from now (within 10 min buffer)
        try storage.saveExpiresAt(Date().addingTimeInterval(300))
        #expect(storage.isTokenExpired())
    }

    @Test("Clear all removes all tokens")
    func clearAllRemovesTokens() throws {
        let storage = makeStorage()

        try storage.saveAccessToken("access")
        try storage.saveRefreshToken("refresh")
        try storage.saveExpiresAt(Date())

        try storage.clearAll()

        #expect(storage.getAccessToken() == nil)
        #expect(storage.getRefreshToken() == nil)
        #expect(storage.getExpiresAt() == nil)
    }
}
