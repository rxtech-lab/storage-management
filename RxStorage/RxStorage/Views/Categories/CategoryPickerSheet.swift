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
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search categories...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
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
            .background(Color(.systemGray6))

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading categories...")
                Spacer()
            } else if viewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") {
                    onSelect(nil)
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadCategories()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
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
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        CategoryPickerSheet(selectedId: nil) { _ in }
    }
}
