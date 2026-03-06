import Foundation

struct AuthConfiguration: Sendable {
    let issuer: String
    let clientID: String
    let scopes: [String]
    let authorizePath: String
    let tokenPath: String
    let userInfoPath: String
    let keychainServiceName: String

    init(
        issuer: String = "https://auth.rxlab.app",
        clientID: String = "",
        scopes: [String] = ["openid", "profile", "email", "offline_access"],
        authorizePath: String = "/api/oauth/authorize",
        tokenPath: String = "/api/oauth/token",
        userInfoPath: String = "/api/oauth/userinfo",
        keychainServiceName: String = "com.rxlab.RxStorageCli"
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.scopes = scopes
        self.authorizePath = authorizePath
        self.tokenPath = tokenPath
        self.userInfoPath = userInfoPath
        self.keychainServiceName = keychainServiceName
    }

    func redirectURI(port: Int) -> String {
        "http://localhost:\(port)/oauth/callback"
    }

    var authorizeURL: URL? {
        URL(string: issuer + authorizePath)
    }

    var tokenURL: URL? {
        URL(string: issuer + tokenPath)
    }

    var userInfoURL: URL? {
        URL(string: issuer + userInfoPath)
    }

    static var fromEnvironment: AuthConfiguration {
        let env = DotEnv.load()
        return AuthConfiguration(
            issuer: env["AUTH_ISSUER"] ?? ProcessInfo.processInfo.environment["AUTH_ISSUER"] ?? "https://auth.rxlab.app",
            clientID: env["AUTH_CLIENT_ID"] ?? ProcessInfo.processInfo.environment["AUTH_CLIENT_ID"] ?? BuildConfig.authClientID ?? ""
        )
    }
}

// MARK: - .env file parser

enum DotEnv {
    static func load(path: String? = nil) -> [String: String] {
        let filePath = path ?? findEnvFile()
        guard let filePath,
              let contents = try? String(contentsOfFile: filePath, encoding: .utf8)
        else { return [:] }

        var result: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }

    private static func findEnvFile() -> String? {
        let fm = FileManager.default
        // Look for .env in current directory, then walk up
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<5 {
            let envPath = dir.appendingPathComponent(".env").path
            if fm.fileExists(atPath: envPath) { return envPath }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }
}
