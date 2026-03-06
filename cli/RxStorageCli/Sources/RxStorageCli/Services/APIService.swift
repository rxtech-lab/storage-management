import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIAsyncHTTPClient
import AsyncHTTPClient

struct BearerAuthMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

enum APIService {
    private static let serverURL: URL = {
        let env = DotEnv.load()
        let urlString =
            env["API_BASE_URL"]
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "http://localhost:3000/api"
        return URL(string: urlString)!
    }()

    static func makeClient() throws -> Client {
        let tokenStorage = FileTokenStorage()
        guard let accessToken = tokenStorage.getAccessToken(),
            !tokenStorage.isTokenExpired()
        else {
            throw APIServiceError.notAuthenticated
        }

        return Client(
            serverURL: serverURL,
            configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: AsyncHTTPClientTransport(),
            middlewares: [BearerAuthMiddleware(token: accessToken)]
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
