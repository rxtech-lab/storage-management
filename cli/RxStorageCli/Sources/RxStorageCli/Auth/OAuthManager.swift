import Foundation

struct AuthUser: Decodable, Sendable {
    let id: String
    let name: String?
    let email: String?
    let image: String?

    enum CodingKeys: String, CodingKey {
        case id, sub, name, email, image, picture
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else if let sub = try container.decodeIfPresent(String.self, forKey: .sub) {
            self.id = sub
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Neither 'id' nor 'sub' found")
            )
        }
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
            ?? container.decodeIfPresent(String.self, forKey: .picture)
    }
}

enum AuthState: Sendable {
    case unknown
    case checking
    case authenticated(AuthUser)
    case unauthenticated
    case authenticating
    case error(String)
}

final class CLIOAuthManager: Sendable {
    private let configuration: AuthConfiguration
    private let tokenStorage: TokenStorageProtocol

    init(configuration: AuthConfiguration) {
        self.configuration = configuration
        self.tokenStorage = TokenStorageFactory.create(serviceName: configuration.keychainServiceName)
    }

    // MARK: - Public API

    func checkExistingAuth() async -> AuthState {
        if let _ = tokenStorage.getAccessToken(), !tokenStorage.isTokenExpired() {
            if let user = try? await fetchUserInfo() {
                return .authenticated(user)
            }
        }

        if tokenStorage.getRefreshToken() != nil {
            if let user = try? await refreshAndFetchUser() {
                return .authenticated(user)
            }
        }

        return .unauthenticated
    }

    func authenticate(onURL: ((URL) -> Void)? = nil) async throws -> AuthUser {
        let codeVerifier = PKCEHelper.generateCodeVerifier()
        let codeChallenge = PKCEHelper.generateCodeChallenge(from: codeVerifier)

        let server = OAuthCallbackServer()
        try await server.start()
        let port = server.port

        let redirectURI = configuration.redirectURI(port: port)
        guard let authorizeURL = buildAuthorizationURL(codeChallenge: codeChallenge, redirectURI: redirectURI) else {
            await server.shutdown()
            throw CLIOAuthError.invalidConfiguration
        }

        onURL?(authorizeURL)
        openBrowser(url: authorizeURL)

        let code: String
        do {
            code = try await server.waitForCallback()
        } catch {
            await server.shutdown()
            throw error
        }

        // Small delay to let the browser receive the HTML response
        try? await Task.sleep(for: .milliseconds(500))
        await server.shutdown()

        let tokenResponse = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier, redirectURI: redirectURI)
        try saveTokens(tokenResponse)

        let user = try await fetchUserInfo()
        return user
    }

    func logout() throws {
        try tokenStorage.clearAll()
    }

    // MARK: - Private

    private func buildAuthorizationURL(codeChallenge: String, redirectURI: String) -> URL? {
        guard var components = URLComponents(string: configuration.issuer + configuration.authorizePath) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String, redirectURI: String) async throws -> TokenResponse {
        guard let tokenURL = configuration.tokenURL else {
            throw CLIOAuthError.invalidConfiguration
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "client_id=\(configuration.clientID)",
            "code_verifier=\(codeVerifier)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CLIOAuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserInfo() async throws -> AuthUser {
        guard let accessToken = tokenStorage.getAccessToken(),
              let userInfoURL = configuration.userInfoURL
        else { throw CLIOAuthError.invalidConfiguration }

        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CLIOAuthError.userInfoFailed
        }

        return try JSONDecoder().decode(AuthUser.self, from: data)
    }

    private func refreshAndFetchUser() async throws -> AuthUser {
        guard let refreshToken = tokenStorage.getRefreshToken(),
              let tokenURL = configuration.tokenURL
        else { throw CLIOAuthError.noRefreshToken }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(configuration.clientID)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CLIOAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveTokens(tokenResponse)
        return try await fetchUserInfo()
    }

    private func saveTokens(_ response: TokenResponse) throws {
        try tokenStorage.saveAccessToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            try tokenStorage.saveRefreshToken(refreshToken)
        }
        if let expiresIn = response.expiresIn {
            try tokenStorage.saveExpiresAt(Date().addingTimeInterval(TimeInterval(expiresIn)))
        }
    }

    private func openBrowser(url: URL) {
        ClipboardService.copy(url.absoluteString)

        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
        #elseif os(Windows)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
        process.arguments = ["/c", "start", url.absoluteString]
        try? process.run()
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [url.absoluteString]
        try? process.run()
        #endif
    }
}

// MARK: - Token Response

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Errors

enum CLIOAuthError: LocalizedError {
    case invalidConfiguration
    case tokenExchangeFailed
    case tokenRefreshFailed
    case userInfoFailed
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Invalid OAuth configuration"
        case .tokenExchangeFailed: return "Failed to exchange code for tokens"
        case .tokenRefreshFailed: return "Failed to refresh token"
        case .userInfoFailed: return "Failed to fetch user info"
        case .noRefreshToken: return "No refresh token available"
        }
    }
}
