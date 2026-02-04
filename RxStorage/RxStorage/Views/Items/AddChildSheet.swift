//
//  AddChildSheet.swift
//  RxStorage
//
//  Sheet for searching and adding child items
//

import RxStorageCore
import SwiftUI

/// Minimal data needed to add a child item (captured synchronously to avoid memory issues)
struct AddChildData: Sendable {
    let itemId: String
    let title: String
    let description: String?
    let categoryId: Int?
    let locationId: Int?
    let authorId: Int?
    let price: Double?
    let visibility: String
}

/// Sheet for searching and adding child items
struct AddChildSheet: View {
    let parentItemId: Int
    let existingChildIds: Set<Int>
    let onChildSelected: (AddChildData) -> Void
    @Binding var isAdding: Bool

    @State private var viewModel: ChildItemSearchViewModel
    @State private var addedChildIds: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    init(
        parentItemId: Int,
        existingChildIds: Set<Int>,
        isAdding: Binding<Bool>,
        onChildSelected: @escaping (AddChildData) -> Void
    ) {
        self.parentItemId = parentItemId
        self.existingChildIds = existingChildIds
        _isAdding = isAdding
        self.onChildSelected = onChildSelected

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
            .overlay {
                if isAdding {
                    LoadingOverlay()
                }
            }
    }

    // MARK: - Items List

    private func itemsList(items: [StorageItem]) -> some View {
        List(items) { item in
            let isAdded = addedChildIds.contains(item.id)
            Button {
                let childData = AddChildData(
                    itemId: String(item.id),
                    title: item.title,
                    description: item.description,
                    categoryId: item.categoryId,
                    locationId: item.locationId,
                    authorId: item.authorId,
                    price: item.price,
                    visibility: item.visibility.rawValue
                )
                addedChildIds.insert(item.id)
                onChildSelected(childData)
            } label: {
                HStack {
                    ItemRow(item: item)

                    Spacer()

                    if isAdded {
                        // Added
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .disabled(isAdded || isAdding)
        }
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AddChildSheet(
            parentItemId: 1,
            existingChildIds: [2, 3],
            isAdding: .constant(false),
            onChildSelected: { _ in }
        )
    }
}
