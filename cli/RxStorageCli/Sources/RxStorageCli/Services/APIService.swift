import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIAsyncHTTPClient
import AsyncHTTPClient

actor AutoRefreshAuthMiddleware: ClientMiddleware {
    private let tokenStorage: FileTokenStorage
    private let configuration: AuthConfiguration
    private var isRefreshing = false
    private var pendingRequests: [CheckedContinuation<Void, Error>] = []

    init(tokenStorage: FileTokenStorage, configuration: AuthConfiguration) {
        self.tokenStorage = tokenStorage
        self.configuration = configuration
    }

    nonisolated func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Proactively refresh if token is about to expire
        if tokenStorage.isTokenExpired(), tokenStorage.getRefreshToken() != nil {
            try await ensureValidToken()
        }

        var modifiedRequest = request
        if let accessToken = tokenStorage.getAccessToken() {
            modifiedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }

        let (response, responseBody) = try await next(modifiedRequest, body, baseURL)

        // Retry on 401
        if response.status == .unauthorized, tokenStorage.getRefreshToken() != nil {
            AppLogger.api.info("Received 401 for \(operationID), attempting token refresh")
            try await ensureValidToken()

            var retryRequest = request
            if let accessToken = tokenStorage.getAccessToken() {
                retryRequest.headerFields[.authorization] = "Bearer \(accessToken)"
            }
            return try await next(retryRequest, body, baseURL)
        }

        return (response, responseBody)
    }

    private func ensureValidToken() async throws {
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append(continuation)
            }
        }

        guard tokenStorage.isTokenExpired() else { return }

        isRefreshing = true
        do {
            try await performTokenRefresh()
            AppLogger.api.info("Token refreshed successfully")
            let continuations = pendingRequests
            pendingRequests = []
            isRefreshing = false
            for c in continuations { c.resume() }
        } catch {
            let continuations = pendingRequests
            pendingRequests = []
            isRefreshing = false
            for c in continuations { c.resume(throwing: error) }
            throw error
        }
    }

    private func performTokenRefresh() async throws {
        guard let refreshToken = tokenStorage.getRefreshToken(),
              let tokenURL = configuration.tokenURL
        else { throw APIServiceError.notAuthenticated }

        var request = HTTPClientRequest(url: tokenURL.absoluteString)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(configuration.clientID)",
        ].joined(separator: "&")
        request.body = .bytes(Data(body.utf8))

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
        guard response.status == .ok else {
            AppLogger.api.error("Token refresh failed with status \(response.status.code)")
            throw APIServiceError.notAuthenticated
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
        }

        let data = Data(buffer: try await response.body.collect(upTo: 1024 * 1024))
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        try tokenStorage.saveAccessToken(tokenResponse.access_token)
        if let newRefresh = tokenResponse.refresh_token {
            try tokenStorage.saveRefreshToken(newRefresh)
        }
        if let expiresIn = tokenResponse.expires_in {
            try tokenStorage.saveExpiresAt(Date().addingTimeInterval(TimeInterval(expiresIn)))
        }
    }
}

enum APIService {
    private static let serverURL: URL = {
        let env = DotEnv.load()
        let urlString =
            env["API_BASE_URL"]
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? BuildConfig.apiBaseURL
            ?? "http://localhost:3000/api"
        return URL(string: urlString)!
    }()

    static func makeClient() throws -> Client {
        let tokenStorage = FileTokenStorage()
        guard tokenStorage.getAccessToken() != nil || tokenStorage.getRefreshToken() != nil
        else {
            throw APIServiceError.notAuthenticated
        }

        let configuration = AuthConfiguration.fromEnvironment
        return Client(
            serverURL: serverURL,
            configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: AsyncHTTPClientTransport(),
            middlewares: [AutoRefreshAuthMiddleware(tokenStorage: tokenStorage, configuration: configuration)]
        )
    }

    static func fetchItems(
        cursor: String? = nil,
        limit: Int? = nil,
        search: String? = nil,
        parentId: String? = nil
    ) async throws -> Components.Schemas.PaginatedItemsResponse {
        AppLogger.api.info("fetchItems: serverURL=\(serverURL.absoluteString)")
        let client = try makeClient()
        do {
            let response = try await client.getItems(
                query: .init(
                    cursor: cursor,
                    limit: limit,
                    search: search,
                    parentId: parentId.map { try! .init(unvalidatedValue: $0) }
                ))
            let result = try response.ok.body.json
            AppLogger.api.info("fetchItems: success, \(result.data.count) items")
            return result
        } catch {
            AppLogger.api.error("fetchItems failed: \(String(describing: error))")
            throw error
        }
    }

    static func fetchItem(id: String) async throws -> Components.Schemas.ItemDetailResponseSchema {
        AppLogger.api.info("fetchItem: id=\(id)")
        let client = try makeClient()
        do {
            let response = try await client.getItem(path: .init(id: id))
            let result = try response.ok.body.json
            AppLogger.api.info("fetchItem: success for \(id)")
            return result
        } catch {
            AppLogger.api.error("fetchItem failed: \(String(describing: error))")
            throw error
        }
    }
    static func getContentPreviewUploadUrls(
        itemId: String,
        items: [ContentPreviewUploadItem]
    ) async throws -> [Components.Schemas.ContentPreviewUploadResponseItemSchema] {
        AppLogger.api.info("getContentPreviewUploadUrls: \(items.count) items for item \(itemId)")
        let client = try makeClient()

        let schemaItems = items.map { item in
            Components.Schemas.ContentPreviewUploadItemSchema(
                filename: item.filename,
                _type: item.type == .video ? .video : .image,
                title: item.title,
                mime_type: item.mimeType,
                size: item.size,
                file_path: item.filePath,
                video_length: item.videoLength
            )
        }

        let response = try await client.getContentPreviewUploadUrls(
            body: .json(.init(item_id: itemId, items: schemaItems))
        )
        let result = try response.created.body.json
        AppLogger.api.info("getContentPreviewUploadUrls: success, \(result.count) URLs")
        return result
    }

    static func uploadToPresignedUrl(url: String, data: Data, contentType: String) async throws {
        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.headers.add(name: "Content-Type", value: contentType)
        request.headers.add(name: "Content-Length", value: "\(data.count)")
        request.body = .bytes(data)

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(120))
        guard (200...299).contains(response.status.code) else {
            throw APIServiceError.uploadFailed(statusCode: Int(response.status.code))
        }
        AppLogger.api.info("uploadToPresignedUrl: success for \(url.prefix(60))...")
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case uploadFailed(statusCode: Int)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please sign in first."
        case .invalidURL: return "Invalid URL."
        case .uploadFailed(let statusCode): return "Upload failed with status \(statusCode)."
        }
    }
}
