import Foundation

enum StorageRoute: Hashable {
    case itemDetail(id: String)
    case uploadContent(itemId: String, itemTitle: String)
}
