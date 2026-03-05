import Foundation
import Vapor

// Actor-based bridge to safely pass the callback code from Vapor route to caller
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
    private nonisolated(unsafe) var app: Application?
    private(set) nonisolated(unsafe) var port: Int = 0

    func start() async throws {
        let app = try await Application.make(.development)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        app.logger.logLevel = .critical
        app.http.server.configuration.logger.logLevel = .critical

        let bridge = self.bridge

        app.get("oauth", "callback") { req -> Response in
            guard let code = req.query[String.self, at: "code"] else {
                await bridge.setError(OAuthCallbackError.missingCode)
                return Response(
                    status: .badRequest,
                    body: .init(string: "<html><body><h1>Error</h1><p>Missing authorization code.</p></body></html>")
                )
            }

            await bridge.setCode(code)

            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html"],
                body: .init(string: """
                    <html><body style="font-family: system-ui; text-align: center; padding: 60px;">
                    <h1>Authentication Successful</h1>
                    <p>You can close this tab and return to the terminal.</p>
                    </body></html>
                    """)
            )
        }

        try await app.server.start()
        self.port = app.http.server.shared.localAddress?.port ?? 0
        self.app = app
    }

    func waitForCallback() async throws -> String {
        try await bridge.waitForResult()
    }

    func shutdown() async {
        if let app {
            await app.server.shutdown()
            try? await app.asyncShutdown()
            self.app = nil
        }
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
