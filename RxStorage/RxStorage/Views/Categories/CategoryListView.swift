//
//  CategoryListView.swift
//  RxStorage
//
//  Category list view
//

import SwiftUI
import RxStorageCore

/// Category list view
struct CategoryListView: View {
    @Binding var selectedCategory: RxStorageCore.Category?

    @State private var viewModel = CategoryListViewModel()
    @State private var showingCreateSheet = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(selectedCategory: Binding<RxStorageCore.Category?> = .constant(nil)) {
        _selectedCategory = selectedCategory
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.categories.isEmpty {
                ProgressView("Loading categories...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "folder",
                    description: Text(viewModel.searchText.isEmpty ? "Create your first category" : "No results found")
                )
            } else {
                categoriesList
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Category", systemImage: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search categories")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .refreshable {
            await viewModel.refreshCategories()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                CategoryFormSheet()
            }
        }
        .task {
            await viewModel.fetchCategories()
        }
    }

    // MARK: - Categories List

    private var categoriesList: some View {
        List(selection: $selectedCategory) {
            ForEach(viewModel.categories) { category in
                NavigationLink(value: category) {
                    CategoryRow(category: category)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            try? await viewModel.deleteCategory(category)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Category row in list
struct CategoryRow: View {
    let category: RxStorageCore.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.name)
                .font(.headline)

            if let description = category.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var selectedCategory: RxStorageCore.Category?
    NavigationStack {
        CategoryListView(selectedCategory: $selectedCategory)
    }
}
