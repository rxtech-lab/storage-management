import OpenAPIRuntime
import SwiftTUI

struct StorageItemList: View, @unchecked Sendable {
    var onSignOut: (() -> Void)?

    @State private var items: [Components.Schemas.ItemResponseSchema] = []
    @State private var selectedItemId: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pagination: Components.Schemas.PaginationInfo?

    var body: some View {
        NavigationStack {
            if isLoading {
                Text("Loading items...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
            } else if items.isEmpty {
                Text("No items found")
            } else {
                VStack {
                    List(selection: $selectedItemId) {
                        ForEach(items, id: \.id) { item in
                            NavigationLink(value: StorageRoute.itemDetail(id: item.id)) {
                                Text("Item: \(item.title) [\(item.visibility.rawValue)]")
                            }
                        }
                    }
                    if let pagination {
                        HStack {
                            if pagination.hasPrevPage {
                                Button("← Prev") {
                                    Task {
                                        await fetchItems(cursor: pagination.prevCursor)
                                    }
                                }
                            }
                            if pagination.hasNextPage {
                                Button("Next →") {
                                    Task {
                                        await fetchItems(cursor: pagination.nextCursor)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: StorageRoute.self) { route in
                    switch route {
                    case .itemDetail(let id):
                        StorageItemDetail(itemId: id)
                    case .uploadContent(let itemId, let itemTitle):
                        UploadContentView(itemId: itemId, itemTitle: itemTitle)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh") {
                    isLoading = true
                    errorMessage = nil
                    Task {
                        await fetchItems()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Sign Out") {
                    onSignOut?()
                }
            }
        }
        .task {
            await fetchItems()
        }
    }

    private func fetchItems(cursor: String? = nil) async {
        do {
            let response = try await APIService.fetchItems(cursor: cursor)
            items = response.data
            pagination = response.pagination
            isLoading = false
        } catch {
            errorMessage = String(describing: error)
            isLoading = false
        }
    }
}
