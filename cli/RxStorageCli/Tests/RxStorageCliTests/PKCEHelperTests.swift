import Testing
@testable import RxStorageCli

@Suite("PKCEHelper Tests")
struct PKCEHelperTests {

    @Test("Code verifier has correct length and characters")
    func codeVerifierFormat() {
        let verifier = PKCEHelper.generateCodeVerifier()

        // Base64url encoded 32 bytes = ~43 characters
        #expect(verifier.count >= 40)
        #expect(verifier.count <= 50)

        // Should only contain base64url characters (no +, /, =)
        #expect(!verifier.contains("+"))
        #expect(!verifier.contains("/"))
        #expect(!verifier.contains("="))
    }

    @Test("Code verifiers are unique")
    func codeVerifierUniqueness() {
        let verifier1 = PKCEHelper.generateCodeVerifier()
        let verifier2 = PKCEHelper.generateCodeVerifier()
        #expect(verifier1 != verifier2)
    }

    @Test("Code challenge is deterministic for same verifier")
    func codeChallengeConsistency() {
        let verifier = "test-verifier-string"
        let challenge1 = PKCEHelper.generateCodeChallenge(from: verifier)
        let challenge2 = PKCEHelper.generateCodeChallenge(from: verifier)
        #expect(challenge1 == challenge2)
    }

    @Test("Code challenge differs for different verifiers")
    func codeChallengeDifference() {
        let challenge1 = PKCEHelper.generateCodeChallenge(from: "verifier-a")
        let challenge2 = PKCEHelper.generateCodeChallenge(from: "verifier-b")
        #expect(challenge1 != challenge2)
    }

    @Test("Code challenge has valid base64url format")
    func codeChallengeFormat() {
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)

        #expect(!challenge.isEmpty)
        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        #expect(!challenge.contains("="))
    }
}
