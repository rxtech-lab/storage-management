import RxStorageCore
import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct MCPSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var response: Components.Schemas.McpClientsResponseSchema?
    @State private var busy = false
    @State private var error: String?
    @State private var disconnectID: String?
    @State private var feedback = false
    private let service = MCPManagementService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(response?.url ?? "Loading…").textSelection(.enabled)
                    Button("Copy MCP URL", systemImage: "doc.on.doc") {
                        guard let url = response?.url else { return }
                        #if os(iOS)
                            UIPasteboard.general.string = url
                        #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        #endif
                        feedback.toggle()
                    }.disabled(response == nil)
                } header: { Text("MCP Server") } footer: {
                    Text("Paste this URL into your MCP client, choose OAuth, then sign in and approve access in the browser. You can disconnect clients below.")
                }
                Section("Connected Clients") {
                    if let response, response.items.isEmpty {
                        ContentUnavailableView("No Connected Clients", systemImage: "network", description: Text("Connect from your preferred MCP client using the server URL."))
                    }
                    ForEach(response?.items ?? [], id: \.id) { client in
                        NavigationLink {
                            Form {
                                Section("Client") {
                                    Text(client.name)
                                    LabeledContent("Permissions", value: client.scope)
                                    LabeledContent("Expires", value: client.expiresAt.formatted())
                                }
                                Section {
                                    Button("Disconnect", role: .destructive) { disconnectID = client.id; feedback.toggle() }
                                }
                            }.navigationTitle(client.name)
                        } label: { Label(client.name, systemImage: "desktopcomputer") }
                    }
                }
            }
            .navigationTitle("MCP Server")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
            .overlay { if busy { ProgressView("Disconnecting…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .disabled(busy)
            .confirmationDialog("Disconnect this client?", isPresented: Binding(get: { disconnectID != nil }, set: { if !$0 { disconnectID = nil } }), titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) {
                    guard let id = disconnectID else { return }
                    disconnectID = nil
                    Task { busy = true; defer { busy = false }; do { try await service.disconnect(id: id); feedback.toggle(); await load() } catch { self.error = error.localizedDescription } }
                }
            } message: { Text("This client's access and refresh tokens will stop working immediately.") }
            .alert("Unable to Complete Action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
            .frame(minWidth: 520, minHeight: 560)
        #endif
            .sensoryFeedback(.success, trigger: feedback)
            .sensoryFeedback(.error, trigger: error != nil)
    }

    private func load() async {
        do { response = try await service.clients() } catch { self.error = error.localizedDescription }
    }
}
