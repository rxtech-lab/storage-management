import Foundation
@testable import RxStorageCore
import Testing

struct ContentSHA256Tests {
    private let hash = String(repeating: "ab", count: 32)

    @Test("Legacy content decodes without SHA-256")
    func legacyContent() throws {
        let content = try JSONDecoder().decode(ContentData.self, from: Data(#"{"title":"legacy"}"#.utf8))
        #expect(content.sha256 == nil)
    }

    @Test("Pending form content preserves SHA-256 in API requests")
    func pendingContent() throws {
        for type in [ContentType.file, .image, .video] {
            let pending = PendingContent(type: type, formData: [
                "title": AnyCodable("file"),
                "sha256": AnyCodable(hash),
            ])
            #expect(pending.asContentRequest.data.sha256 == hash)
            let payload = pending.asContentRequest.data.toAPIData(for: type)
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
            #expect(json["sha256"] as? String == hash)
        }
    }

    @Test("Content responses expose SHA-256 for editing")
    func responseContent() throws {
        let json = #"{"id":"content","itemId":"item","type":"file","data":{"title":"file","sha256":"\#(hash)"},"createdAt":"2026-11-15T00:00:00Z","updatedAt":"2026-11-15T00:00:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let content = try decoder.decode(Content.self, from: Data(json.utf8))
        #expect(content.contentData.sha256 == hash)
    }
}
