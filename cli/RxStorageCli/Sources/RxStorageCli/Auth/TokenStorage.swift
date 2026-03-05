import Foundation

protocol TokenStorageProtocol: Sendable {
    func saveAccessToken(_ token: String) throws
    func getAccessToken() -> String?
    func saveRefreshToken(_ token: String) throws
    func getRefreshToken() -> String?
    func saveExpiresAt(_ date: Date) throws
    func getExpiresAt() -> Date?
    func isTokenExpired() -> Bool
    func clearAll() throws
}

enum TokenStorageFactory {
    static func create(serviceName: String) -> TokenStorageProtocol {
        FileTokenStorage()
    }
}

// MARK: - File-based Token Storage (cross-platform)

final class FileTokenStorage: TokenStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".rxstorage")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("tokens.json")
    }

    private struct TokenData: Codable {
        var accessToken: String?
        var refreshToken: String?
        var expiresAt: Date?
    }

    private func load() -> TokenData {
        guard let data = try? Data(contentsOf: fileURL),
              let tokens = try? JSONDecoder().decode(TokenData.self, from: data)
        else { return TokenData() }
        return tokens
    }

    private func save(_ tokens: TokenData) throws {
        let data = try JSONEncoder().encode(tokens)
        try data.write(to: fileURL, options: .atomic)
    }

    func saveAccessToken(_ token: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var tokens = load()
        tokens.accessToken = token
        try save(tokens)
    }

    func getAccessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return load().accessToken
    }

    func saveRefreshToken(_ token: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var tokens = load()
        tokens.refreshToken = token
        try save(tokens)
    }

    func getRefreshToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return load().refreshToken
    }

    func saveExpiresAt(_ date: Date) throws {
        lock.lock()
        defer { lock.unlock() }
        var tokens = load()
        tokens.expiresAt = date
        try save(tokens)
    }

    func getExpiresAt() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return load().expiresAt
    }

    func isTokenExpired() -> Bool {
        guard let expiresAt = getExpiresAt() else { return true }
        return expiresAt.timeIntervalSinceNow < 600
    }

    func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
