//
//  ParentItemPickerSheet.swift
//  RxStorage
//
//  Searchable parent item picker sheet with pagination
//

import RxStorageCore
import SwiftUI

/// Searchable parent item picker sheet
struct ParentItemPickerSheet: View {
    let selectedId: Int?
    let excludeItemId: Int?
    let onSelect: (StorageItem?) -> Void

    @State private var viewModel: ParentItemPickerViewModel
    @Environment(\.dismiss) private var dismiss

    init(selectedId: Int?, excludeItemId: Int? = nil, onSelect: @escaping (StorageItem?) -> Void) {
        self.selectedId = selectedId
        self.excludeItemId = excludeItemId
        self.onSelect = onSelect
        _viewModel = State(initialValue: ParentItemPickerViewModel(excludeItemId: excludeItemId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search items...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                #if os(iOS)
                    .autocorrectionDisabled()
                #endif
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.search("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            #if os(iOS)
                .background(Color(.systemGray6))
            #elseif os(macOS)
                .background(Color(nsColor: .quaternaryLabelColor))
            #endif

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading items...")
                Spacer()
            } else if viewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if viewModel.displayItems.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Items" : "No Results",
                    systemImage: "shippingbox",
                    description: Text(viewModel.searchText.isEmpty ? "No items available" : "No items found")
                )
            } else {
                itemList
            }
        }
        .navigationTitle("Select Parent Item")
        #if os(iOS)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("parent-picker-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        onSelect(nil)
                        dismiss()
                    }
                    .accessibilityIdentifier("parent-picker-clear-button")
                }
            }
            .task {
                await viewModel.loadItems()
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.search(newValue)
            }
    }

    private var itemList: some View {
        List {
            ForEach(viewModel.displayItems) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .foregroundStyle(.primary)
                            if let description = item.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if item.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .accessibilityIdentifier("parent-picker-row-\(item.id)")
                .onAppear {
                    if viewModel.shouldLoadMore(for: item) {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ParentItemPickerSheet(selectedId: nil) { _ in }
    }
}
