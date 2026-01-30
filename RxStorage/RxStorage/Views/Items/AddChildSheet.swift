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
        self._isAdding = isAdding
        self.onChildSelected = onChildSelected

        // Exclude parent and existing children
        var excluded = existingChildIds
        excluded.insert(parentItemId)
        _viewModel = State(initialValue: ChildItemSearchViewModel(excludedItemIds: excluded))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if viewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No items found matching '\(viewModel.searchText)'")
                )
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "Search for Items",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search for items to add as children")
                )
            } else {
                resultsList
            }
        }
        .navigationTitle("Add Child Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .overlay {
            if isAdding {
                LoadingOverlay()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search items...", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.search(newValue)
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(viewModel.searchResults) { item in
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
