//
//  ChildrenListSheet.swift
//  RxStorage
//
//  Sheet for browsing all child items with search and pagination
//

import RxStorageCore
import SwiftUI

/// Sheet that displays all child items for an item with search and load more
struct ChildrenListSheet: View {
    let parentId: String
    let isViewOnly: Bool

    @State private var children: [StorageItem] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var nextCursor: String?
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var selectedChildForEdit: StorageItem?
    @Environment(\.dismiss) private var dismiss

    private let itemService: ItemServiceProtocol = ItemService()
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && children.isEmpty {
                    ProgressView("Loading children...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if children.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Child Items" : "No Results",
                        systemImage: searchText.isEmpty ? "list.bullet.indent" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "This item has no child items." : "No child items match your search.")
                    )
                } else {
                    childrenList
                }
            }
            .navigationTitle("Child Items")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .searchable(text: $searchText, prompt: "Search children")
                .overlay {
                    if isSearching && !children.isEmpty {
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
                        await fetchChildren(search: newValue.isEmpty ? nil : newValue)
                        isSearching = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(item: $selectedChildForEdit) { child in
                    NavigationStack {
                        ItemFormSheet(item: child)
                    }
                }
                .task {
                    await fetchChildren()
                }
        }
    }

    private var childrenList: some View {
        List {
            ForEach(children) { child in
                NavigationLink(value: child) {
                    ItemRow(item: child)
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
        .navigationDestination(for: StorageItem.self) { child in
            ItemDetailView(itemId: child.id, isViewOnly: isViewOnly)
        }
    }

    // MARK: - Data Fetching

    private func fetchChildren(search: String? = nil) async {
        isLoading = true

        do {
            let result = try await itemService.fetchItemsPaginated(
                filters: ItemFilters(
                    parentId: parentId,
                    search: search,
                    limit: pageSize
                )
            )
            children = result.data
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            print("Failed to fetch children: \(error)")
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let result = try await itemService.fetchItemsPaginated(
                filters: ItemFilters(
                    parentId: parentId,
                    search: searchText.isEmpty ? nil : searchText,
                    cursor: cursor,
                    limit: pageSize
                )
            )
            children.append(contentsOf: result.data)
            hasMore = result.pagination.hasNextPage
            nextCursor = result.pagination.nextCursor
        } catch {
            print("Failed to load more children: \(error)")
        }

        isLoadingMore = false
    }
}
