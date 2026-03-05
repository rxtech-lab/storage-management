import OpenAPIRuntime
import SwiftTUI

struct StorageItemDetail: View, @unchecked Sendable {
    let itemId: String

    @State private var item: Components.Schemas.ItemDetailResponseSchema?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                Text("Loading...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
            } else if let item {
                Text(item.title).bold()

                if let description = item.description {
                    Text(description)
                }

                Divider()

                Text("Visibility: \(item.visibility.rawValue)")
                Text("Quantity: \(item.quantity)")

                if let category = item.category {
                    Text("Category: \(category.value1.name)")
                }

                if let location = item.location {
                    Text("Location: \(location.value1.title)")
                }

                if let author = item.author {
                    Text("Author: \(author.value1.name)")
                }

                if !item.children.isEmpty {
                    Divider()
                    Text("Children (\(item.children.count)):")
                    ForEach(item.children, id: \.id) { child in
                        Text("  - \(child.title)")
                    }
                }
            } else {
                Text("Item not found")
            }

            Divider()
            Text("Actions:").bold()
            NavigationLink("Upload file content", value: StorageRoute.uploadContent(itemId: itemId))
                .background(.brightBlue)
        }
        .task(id: itemId) {
            await fetchItem()
        }
    }

    private func fetchItem() async {
        do {
            let detail = try await APIService.fetchItem(id: itemId)
            await MainActor.run {
                item = detail
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
