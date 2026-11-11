import Foundation

public struct ItemAIRequest: Encodable, Sendable {
    public var prompt: String
    public var title: String
    public var description: String
    public var originalQrCode: String
    public var images: [String]
    public var webSearch: Bool

    public init(prompt: String = "", title: String = "", description: String = "", originalQrCode: String = "", images: [String] = [], webSearch: Bool = true) {
        self.prompt = prompt
        self.title = title
        self.description = description
        self.originalQrCode = originalQrCode
        self.images = images
        self.webSearch = webSearch
    }
}

public struct ItemAIDraft: Codable, Sendable {
    public var title: String
    public var description: String
    public var originalQrCode: String?
    public var category: String?
    public var author: String?
    public var tags: [String]
}

public struct ItemAISource: Codable, Sendable {
    public var title: String
    public var url: String
}

public struct ItemAIResponse: Codable, Sendable {
    public var draft: ItemAIDraft
    public var sources: [ItemAISource]
}

public struct BarcodeLookupResponse: Codable, Sendable {
    public var barcode: String
    public var itemUrl: String?
    public var result: ItemAIResponse?
}

public struct ItemAIRelations: Codable, Sendable {
    public var categoryId: String?
    public var authorId: String?
    public var tagIds: [String]
}

public struct ItemAIService: Sendable {
    public init() {}

    public func lookupBarcode(_ barcode: String, inventory: Bool = true) async throws -> BarcodeLookupResponse {
        struct Input: Encodable { let barcode: String; let inventory: Bool }
        return try await post("/api/v1/items/lookup", body: Input(barcode: barcode, inventory: inventory))
    }

    public func generate(_ input: ItemAIRequest) async throws -> ItemAIResponse {
        try await post("/api/v1/items/ai", body: input)
    }

    public func createRelations(category: String?, author: String?, tags: [String]) async throws -> ItemAIRelations {
        struct Input: Encodable {
            let category: String?
            let author: String?
            let tags: [String]
            /// Explicit nulls match the API's review contract.
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(category, forKey: .category)
                try container.encode(author, forKey: .author)
                try container.encode(tags, forKey: .tags)
            }

            enum CodingKeys: String, CodingKey { case category, author, tags }
        }
        return try await post("/api/v1/items/ai/relations", body: Input(category: category, author: author, tags: tags))
    }

    private struct Failure: Decodable { let error: String }

    private func post<Input: Encodable, Output: Decodable>(_ path: String, body: Input) async throws -> Output {
        guard let url = URL(string: AppConfiguration.shared.apiBaseURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainTokenStorage(serviceName: "com.rxlab.RxStorage").getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200 ..< 300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error ?? "Could not research item"
            throw APIError.serverError(message)
        }
        return try JSONDecoder().decode(Output.self, from: data)
    }
}
