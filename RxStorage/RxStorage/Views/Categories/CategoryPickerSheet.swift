//
//  CategoryPickerSheet.swift
//  RxStorage
//
//  Searchable category picker sheet with pagination
//

import RxStorageCore
import SwiftUI

/// Searchable category picker sheet
struct CategoryPickerSheet: View {
    let selectedId: Int?
    let onSelect: (RxStorageCore.Category?) -> Void

    @State private var viewModel = CategoryPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading categories...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.displayItems.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Categories" : "No Results",
                    systemImage: "folder",
                    description: Text(viewModel.searchText.isEmpty ? "Create a category first" : "No categories found")
                )
            } else {
                categoryList
            }
        }
        .navigationTitle("Select Category")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("category-picker-cancel-button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") {
                    onSelect(nil)
                    dismiss()
                }
                .accessibilityIdentifier("category-picker-clear-button")
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search categories")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .task {
            await viewModel.loadCategories()
        }
    }

    private var categoryList: some View {
        List {
            ForEach(viewModel.displayItems) { category in
                Button {
                    onSelect(category)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .foregroundStyle(.primary)
                            if let description = category.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if category.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .accessibilityIdentifier("category-picker-row-\(category.id)")
                .onAppear {
                    if viewModel.shouldLoadMore(for: category) {
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
        CategoryPickerSheet(selectedId: nil) { _ in }
    }
}
