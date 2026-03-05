import Foundation
import Testing
@testable import RxStorageCli

@Suite("AuthConfiguration Tests")
struct AuthConfigurationTests {

    @Test("Default configuration has correct issuer")
    func defaultIssuer() {
        let config = AuthConfiguration()
        #expect(config.issuer == "https://auth.rxlab.app")
    }

    @Test("Default scopes include required OAuth scopes")
    func defaultScopes() {
        let config = AuthConfiguration()
        #expect(config.scopes.contains("openid"))
        #expect(config.scopes.contains("profile"))
        #expect(config.scopes.contains("email"))
        #expect(config.scopes.contains("offline_access"))
    }

    @Test("Redirect URI includes port")
    func redirectURIContainsPort() {
        let config = AuthConfiguration()
        let uri = config.redirectURI(port: 8080)
        #expect(uri == "http://localhost:8080/oauth/callback")
    }

    @Test("Authorize URL is correctly built")
    func authorizeURL() {
        let config = AuthConfiguration(issuer: "https://auth.example.com")
        let url = config.authorizeURL
        #expect(url?.absoluteString == "https://auth.example.com/api/oauth/authorize")
    }

    @Test("Token URL is correctly built")
    func tokenURL() {
        let config = AuthConfiguration(issuer: "https://auth.example.com")
        let url = config.tokenURL
        #expect(url?.absoluteString == "https://auth.example.com/api/oauth/token")
    }

    @Test("UserInfo URL is correctly built")
    func userInfoURL() {
        let config = AuthConfiguration(issuer: "https://auth.example.com")
        let url = config.userInfoURL
        #expect(url?.absoluteString == "https://auth.example.com/api/oauth/userinfo")
    }
}
