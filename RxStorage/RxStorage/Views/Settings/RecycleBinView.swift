import RxStorageCore
import SwiftUI

struct RecycleBinView: View {
    @Environment(EventViewModel.self) private var eventViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var response: Components.Schemas.RecycleBinResponseSchema?
    @State private var busy = false
    @State private var error: String?
    @State private var deletionID: String?
    @State private var confirmEmpty = false
    @State private var feedback = false
    @State private var status = ""
    private let service = MCPManagementService()

    var body: some View {
        NavigationStack {
            List {
                if let response, response.items.isEmpty {
                    ContentUnavailableView("Recycle Bin Is Empty", systemImage: "trash")
                }
                ForEach(response?.items ?? [], id: \.id) { item in
                    NavigationLink(item.title) {
                        Form {
                            Section("Deleted Item") {
                                Text(item.title)
                                if let date = item.deletedAt { LabeledContent("Deleted", value: date.formatted()) }
                            }
                            Section {
                                Button("Restore", systemImage: "arrow.uturn.backward") { perform("Restoring…") { try await service.restore(id: item.id); eventViewModel.emit(.itemCreated(id: item.id)) } }
                                Button("Delete Permanently", role: .destructive) { deletionID = item.id; feedback.toggle() }
                            }
                        }.navigationTitle(item.title)
                    }
                }
            }
            .navigationTitle("Recycle Bin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Clear All", role: .destructive) { confirmEmpty = true; feedback.toggle() }.disabled(response?.items.isEmpty != false) }
            }
            .task { await load() }
            .refreshable { await load() }
            .overlay { if busy { ProgressView(status).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .disabled(busy)
            .confirmationDialog("Delete this item permanently?", isPresented: Binding(get: { deletionID != nil }, set: { if !$0 { deletionID = nil } }), titleVisibility: .visible) {
                Button("Delete Permanently", role: .destructive) {
                    guard let id = deletionID else { return }; deletionID = nil
                    perform("Deleting…") { try await service.purge(id: id) }
                }
            } message: { Text("This removes the item and its attachments and cannot be undone.") }
            .confirmationDialog("Empty the recycle bin?", isPresented: $confirmEmpty, titleVisibility: .visible) {
                Button("Delete All Permanently", role: .destructive) { perform("Clearing Recycle Bin…") { try await service.emptyBin() } }
            } message: { Text("Every item in the recycle bin will be permanently deleted. This cannot be undone.") }
            .alert("Unable to Complete Action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
            .frame(minWidth: 520, minHeight: 560)
        #endif
            .sensoryFeedback(.success, trigger: feedback)
            .sensoryFeedback(.error, trigger: error != nil)
    }

    private func perform(_ message: String, action: @escaping @MainActor () async throws -> Void) {
        status = message; busy = true
        Task { defer { busy = false }; do { try await action(); feedback.toggle(); await load() } catch { self.error = error.localizedDescription; await load() } }
    }

    private func load() async {
        do { response = try await service.recycleBin() } catch { self.error = error.localizedDescription }
    }
}
