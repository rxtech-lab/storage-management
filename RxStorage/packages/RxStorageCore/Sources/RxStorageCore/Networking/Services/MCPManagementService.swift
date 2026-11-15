import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "MCPManagementService")

public struct MCPManagementService: Sendable {
    public init() {}

    @APICall(.ok)
    public func clients() async throws -> Components.Schemas.McpClientsResponseSchema {
        try await StorageAPIClient.shared.client.listMcpClients(.init())
    }

    @APICall(.ok)
    public func recycleBin() async throws -> Components.Schemas.RecycleBinResponseSchema {
        try await StorageAPIClient.shared.client.listRecycleBin(.init())
    }

    public func disconnect(id: String) async throws {
        let result = try await StorageAPIClient.shared.client.disconnectMcpClient(.init(path: .init(id: id)))
        guard case .noContent = result else { throw APIError.serverError("Could not disconnect client. Please try again.") }
    }

    public func restore(id: String) async throws {
        let result = try await StorageAPIClient.shared.client.restoreRecycledItem(.init(path: .init(id: id)))
        guard case .noContent = result else { throw APIError.serverError("Could not restore item. Please try again.") }
    }

    public func purge(id: String) async throws {
        let result = try await StorageAPIClient.shared.client.purgeRecycledItem(.init(path: .init(id: id)))
        guard case .noContent = result else { throw APIError.serverError("Could not permanently delete item. Please try again.") }
    }

    public func emptyBin() async throws {
        let result = try await StorageAPIClient.shared.client.emptyRecycleBin(.init())
        guard case .noContent = result else { throw APIError.serverError("Could not empty recycle bin. Refresh and try again.") }
    }
}
