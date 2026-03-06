import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

// Actor-based bridge to safely pass the callback code from NIO route to caller
actor CallbackBridge {
    private var continuation: CheckedContinuation<String, any Error>?
    private var receivedCode: String?
    private var receivedError: (any Error)?

    func setCode(_ code: String) {
        if let continuation {
            continuation.resume(returning: code)
            self.continuation = nil
        } else {
            receivedCode = code
        }
    }

    func setError(_ error: any Error) {
        if let continuation {
            continuation.resume(throwing: error)
            self.continuation = nil
        } else {
            receivedError = error
        }
    }

    func waitForResult() async throws -> String {
        if let code = receivedCode {
            return code
        }
        if let error = receivedError {
            throw error
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }
}

final class OAuthCallbackServer: Sendable {
    let bridge = CallbackBridge()
    private nonisolated(unsafe) var channel: Channel?
    private nonisolated(unsafe) var group: EventLoopGroup?
    private(set) nonisolated(unsafe) var port: Int = 0

    func start() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group
        let bridge = self.bridge

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(OAuthHTTPHandler(bridge: bridge))
                }
            }
            .childChannelOption(.maxMessagesPerRead, value: 1)

        let channel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
        self.channel = channel

        if let localAddress = channel.localAddress {
            self.port = localAddress.port ?? 0
        }
    }

    func waitForCallback() async throws -> String {
        try await bridge.waitForResult()
    }

    func shutdown() async {
        try? await channel?.close()
        try? await group?.shutdownGracefully()
        self.channel = nil
        self.group = nil
    }
}

private final class OAuthHTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let bridge: CallbackBridge
    private var uri: String = ""

    init(bridge: CallbackBridge) {
        self.bridge = bridge
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            self.uri = head.uri
        case .body:
            break
        case .end:
            handleRequest(context: context)
        }
    }

    private func handleRequest(context: ChannelHandlerContext) {
        let uri = self.uri

        guard uri.hasPrefix("/oauth/callback") else {
            sendResponse(context: context, status: .notFound, body: "<html><body><h1>Not Found</h1></body></html>")
            return
        }

        let queryParams = parseQuery(from: uri)

        guard let code = queryParams["code"] else {
            let bridge = self.bridge
            Task { await bridge.setError(OAuthCallbackError.missingCode) }
            sendResponse(context: context, status: .badRequest, body: "<html><body><h1>Error</h1><p>Missing authorization code.</p></body></html>")
            return
        }

        let bridge = self.bridge
        Task { await bridge.setCode(code) }
        sendResponse(context: context, status: .ok, body: """
            <html><body style="font-family: system-ui; text-align: center; padding: 60px;">
            <h1>Authentication Successful</h1>
            <p>You can close this tab and return to the terminal.</p>
            </body></html>
            """)
    }

    private func sendResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, body: String) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        let bodyData = ByteBuffer(string: body)
        headers.add(name: "Content-Length", value: "\(bodyData.readableBytes)")
        headers.add(name: "Connection", value: "close")

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(bodyData))), promise: nil)
        // ChannelHandlerContext is safe to use in whenComplete on the same event loop
        nonisolated(unsafe) let ctx = context
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            ctx.close(promise: nil)
        }
    }

    private func parseQuery(from uri: String) -> [String: String] {
        guard let queryStart = uri.firstIndex(of: "?") else { return [:] }
        let query = String(uri[uri.index(after: queryStart)...])
        var params: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                params[key] = value
            }
        }
        return params
    }
}

enum OAuthCallbackError: LocalizedError {
    case missingCode
    case serverStartFailed

    var errorDescription: String? {
        switch self {
        case .missingCode:
            return "Authorization code not found in callback"
        case .serverStartFailed:
            return "Failed to start local callback server"
        }
    }
}
