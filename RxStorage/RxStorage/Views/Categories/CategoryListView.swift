//
//  CategoryListView.swift
//  RxStorage
//
//  Category list view
//

import RxStorageCore
import SwiftUI

/// Category list view
struct CategoryListView: View {
    @Binding var selectedCategory: RxStorageCore.Category?
    let horizontalSizeClass: UserInterfaceSizeClass

    @State private var viewModel = CategoryListViewModel()
    @State private var showingCreateSheet = false
    @State private var isRefreshing = false
    @State private var errorViewModel = ErrorViewModel()
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var categoryToDelete: RxStorageCore.Category?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedCategory: Binding<RxStorageCore.Category?> = .constant(nil)) {
        self.horizontalSizeClass = horizontalSizeClass
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
        .task {
            // Listen for category events and refresh
            for await event in eventViewModel.stream {
                switch event {
                case .categoryCreated, .categoryUpdated, .categoryDeleted:
                    isRefreshing = true
                    await viewModel.refreshCategories()
                    isRefreshing = false
                default:
                    break
                }
            }
        }
        .overlay {
            if isRefreshing {
                LoadingOverlay(title: "Refreshing...")
            }
        }
        .confirmationDialog(
            title: "Delete Category",
            message: "Are you sure you want to delete \"\(categoryToDelete?.name ?? "")\"? This action cannot be undone.",
            confirmButtonTitle: "Delete",
            isPresented: $showDeleteConfirmation,
            onConfirm: {
                if let category = categoryToDelete {
                    Task {
                        do {
                            let deletedId = try await viewModel.deleteCategory(category)
                            eventViewModel.emit(.categoryDeleted(id: deletedId))
                        } catch {
                            errorViewModel.showError(error)
                        }
                        categoryToDelete = nil
                    }
                }
            },
            onCancel: { categoryToDelete = nil }
        )
        .onChange(of: viewModel.error != nil) { _, hasError in
            if hasError, let error = viewModel.error {
                errorViewModel.showError(error)
            }
        }
        .showViewModelError(errorViewModel)
    }

    // MARK: - Categories List

    private var categoriesList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedCategory) {
            ForEach(viewModel.categories) { category in
                NavigationLink(value: category) {
                    CategoryRow(category: category)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        categoryToDelete = category
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if shouldLoadMore(for: category) {
                        Task {
                            await viewModel.loadMoreCategories()
                        }
                    }
                }
            }

            // Loading more indicator
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

    // MARK: - Pagination Helper

    private func shouldLoadMore(for category: RxStorageCore.Category) -> Bool {
        guard let index = viewModel.categories.firstIndex(where: { $0.id == category.id }) else {
            return false
        }
        let threshold = 3
        return index >= viewModel.categories.count - threshold &&
            viewModel.hasNextPage &&
            !viewModel.isLoadingMore &&
            !viewModel.isLoading
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
        CategoryListView(horizontalSizeClass: .compact, selectedCategory: $selectedCategory)
    }
}
