import Foundation
import Testing
import Vapor
import XCTVapor
@testable import RxStorageCli

@Suite("OAuthCallbackServer Tests", .serialized)
struct OAuthCallbackServerTests {

    @Test("Server starts and returns a valid port")
    func serverStartsWithPort() async throws {
        let server = OAuthCallbackServer()
        try await server.start()
        defer { Task { await server.shutdown() } }
        #expect(server.port > 0)
        await server.shutdown()
    }

    @Test("Server receives callback with authorization code")
    func callbackReceivesCode() async throws {
        let server = OAuthCallbackServer()
        try await server.start()
        defer { Task { await server.shutdown() } }
        let port = server.port
        let bridge = server.bridge

        // Start waiting for result in a separate task
        let codeTask = Task {
            try await bridge.waitForResult()
        }

        // Simulate the OAuth redirect by making a request to the callback URL
        let url = URL(string: "http://127.0.0.1:\(port)/oauth/callback?code=test-auth-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200)

        let receivedCode = try await codeTask.value
        #expect(receivedCode == "test-auth-code")

        await server.shutdown()
    }

    @Test("Server returns error page when code is missing")
    func callbackMissingCode() async throws {
        let server = OAuthCallbackServer()
        try await server.start()
        defer { Task { await server.shutdown() } }
        let port = server.port

        let url = URL(string: "http://127.0.0.1:\(port)/oauth/callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 400)

        await server.shutdown()
    }
}
