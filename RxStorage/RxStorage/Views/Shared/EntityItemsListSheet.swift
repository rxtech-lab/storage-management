//
//  EntityItemsListSheet.swift
//  RxStorage
//
//  Sheet for browsing all items belonging to an entity with search and pagination
//

import RxStorageCore
import SwiftUI

/// Filter type for entity items list
enum EntityItemFilter {
    case author(id: String)
    case category(id: String)
    case location(id: String)
    case tag(id: String)

    var title: String {
        switch self {
        case .author: "Items by Author"
        case .category: "Items in Category"
        case .location: "Items at Location"
        case .tag: "Items with Tag"
        }
    }

    func toItemFilters(search: String? = nil, cursor: String? = nil, limit: Int? = nil) -> ItemFilters {
        switch self {
        case let .author(id):
            ItemFilters(authorId: id, search: search, cursor: cursor, limit: limit)
        case let .category(id):
            ItemFilters(categoryId: id, search: search, cursor: cursor, limit: limit)
        case let .location(id):
            ItemFilters(locationId: id, search: search, cursor: cursor, limit: limit)
        case let .tag(id):
            ItemFilters(search: search, cursor: cursor, limit: limit, tagIds: [id])
        }
    }
}

/// Sheet that displays all items for an entity with search and load more
struct EntityItemsListSheet: View {
    let filter: EntityItemFilter

    @State private var items: [StorageItem] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var nextCursor: String?
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    private let itemService: ItemServiceProtocol = ItemService()
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading items...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Items" : "No Results",
                        systemImage: searchText.isEmpty ? "shippingbox" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "No items found for this entity." : "No items match your search.")
                    )
                } else {
                    itemsList
                }
            }
            .navigationTitle(filter.title)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .searchable(text: $searchText, prompt: "Search items")
                .overlay {
                    if isSearching && !items.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    isSearching = true
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        await fetchItems(search: newValue.isEmpty ? nil : newValue)
                        isSearching = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task {
                    await fetchItems()
                }
        }
    }

    private var itemsList: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
                .buttonStyle(.plain)
            }

            if hasMore {
                Section {
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .foregroundStyle(.blue)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        .frame(minWidth: 400, minHeight: 300)
        #endif
        .navigationDestination(for: StorageItem.self) { item in
            ItemDetailView(itemId: item.id)
        }
    }

    // MARK: - Data Fetching

    private func fetchItems(search: String? = nil) async {
        isLoading = true

        do {
            let filters = filter.toItemFilters(search: search, limit: pageSize)
            let result = try await itemService.fetchItemsPaginated(filters: filters)
            items = result.data
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            print("Failed to fetch entity items: \(error)")
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let filters = filter.toItemFilters(
                search: searchText.isEmpty ? nil : searchText,
                cursor: cursor,
                limit: pageSize
            )
            let result = try await itemService.fetchItemsPaginated(filters: filters)
            items.append(contentsOf: result.data)
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            print("Failed to load more entity items: \(error)")
        }

        isLoadingMore = false
    }
}
