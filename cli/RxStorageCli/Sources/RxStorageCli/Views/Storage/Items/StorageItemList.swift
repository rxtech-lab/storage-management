import OpenAPIRuntime
import SwiftTUI

struct StorageItemList: View, @unchecked Sendable {
    @State private var items: [Components.Schemas.ItemResponseSchema] = []
    @State private var selectedItemId: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if isLoading {
                Text("Loading items...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
            } else if items.isEmpty {
                Text("No items found")
            } else {
                List(selection: $selectedItemId) {
                    ForEach(items, id: \.id) { item in
                        NavigationLink(value: StorageRoute.itemDetail(id: item.id)) {
                            Text("Item: \(item.title) [\(item.visibility.rawValue)]")
                        }
                    }
                }
                .navigationDestination(for: StorageRoute.self) { route in
                    switch route {
                    case .itemDetail(let id):
                        StorageItemDetail(itemId: id)
                    case .uploadContent(let itemId):
                        UploadContentView(itemId: itemId)
                    }
                }
            }
        }
        .task {
            await fetchItems()
        }
    }

    private func fetchItems() async {
        do {
            let response = try await APIService.fetchItems()
            await MainActor.run {
                items = response.data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = String(describing: error)
                isLoading = false
            }
        }
    }
}
