//
//  AddChildSheet.swift
//  RxStorage
//
//  Sheet for searching and adding child items
//

import RxStorageCore
import SwiftUI

/// Sheet for searching and adding child items
struct AddChildSheet: View {
    let parentItemId: String
    let parentTitle: String
    let existingChildIds: Set<String>
    let onChildMoved: (MoveStockResult) -> Void

    @State private var viewModel: ChildItemSearchViewModel
    @State private var addedChildIds: Set<String> = []
    /// Item whose move (source, amount) is being chosen
    @State private var pendingMoveItem: StorageItem?
    @Environment(\.dismiss) private var dismiss

    init(
        parentItemId: String,
        parentTitle: String,
        existingChildIds: Set<String>,
        onChildMoved: @escaping (MoveStockResult) -> Void
    ) {
        self.parentItemId = parentItemId
        self.parentTitle = parentTitle
        self.existingChildIds = existingChildIds
        self.onChildMoved = onChildMoved

        // Exclude parent and existing children
        var excluded = existingChildIds
        excluded.insert(parentItemId)
        _viewModel = State(initialValue: ChildItemSearchViewModel(excludedItemIds: excluded))
    }

    var body: some View {
        Group {
            if viewModel.isSearching || viewModel.isLoadingDefaults {
                VStack {
                    Spacer()
                    ProgressView(viewModel.isSearching ? "Searching..." : "Loading...")
                    Spacer()
                }
            } else if viewModel.searchText.isEmpty {
                // Show default items when not searching
                if viewModel.defaultItems.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "tray",
                        description: Text("No items available to add as children")
                    )
                } else {
                    itemsList(items: viewModel.defaultItems)
                }
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No items found matching '\(viewModel.searchText)'")
                )
            } else {
                itemsList(items: viewModel.searchResults)
            }
        }
        .task {
            await viewModel.loadDefaultItems()
        }
        .navigationTitle("Add Child Item")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search items")
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.search(newValue)
            }
            .sheet(item: $pendingMoveItem) { item in
                NavigationStack {
                    MoveStockSheet(
                        itemId: item.id,
                        itemTitle: item.title,
                        destinationParentId: parentItemId,
                        destinationTitle: parentTitle
                    ) { result in
                        addedChildIds.insert(result.itemId)
                        onChildMoved(result)
                    }
                }
            }
    }

    // MARK: - Items List

    private func itemsList(items: [StorageItem]) -> some View {
        List(items) { item in
            let isAdded = addedChildIds.contains(item.id)
            Button {
                pendingMoveItem = item
            } label: {
                HStack {
                    ItemRow(item: item)

                    Spacer()

                    if isAdded {
                        // Added; stays tappable so more units can be moved
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
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
    }
}

#Preview {
    NavigationStack {
        AddChildSheet(
            parentItemId: "1",
            parentTitle: "Box",
            existingChildIds: ["2", "3"],
            onChildMoved: { _ in }
        )
    }
}
