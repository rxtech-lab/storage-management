//
//  ItemListView.swift
//  RxStorage
//
//  Item list view with filtering and search
//

import RxStorageCore
import SwiftUI

/// Item list view
struct ItemListView: View {
    @Binding var selectedItem: StorageItem?
    @State private var viewModel = ItemListViewModel()
    @Environment(EventViewModel.self) private var eventViewModel
    @Environment(NavigationManager.self) private var navigationManager

    let horizontalSizeClass: UserInterfaceSizeClass

    /// Optional callback for navigation (used when ItemListView is embedded in TabView)
    /// When provided, this is called to navigate to an item instead of using selectedItem binding
    var onNavigateToItem: ((StorageItem) -> Void)?

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(
        horizontalSizeClass: UserInterfaceSizeClass,
        selectedItem: Binding<StorageItem?> = .constant(nil),
        onNavigateToItem: ((StorageItem) -> Void)? = nil
    ) {
        _selectedItem = selectedItem
        self.horizontalSizeClass = horizontalSizeClass
        self.onNavigateToItem = onNavigateToItem
    }

    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    @State private var errorViewModel = ErrorViewModel()

    /// Refresh state
    @State private var isRefreshing = false

    // Delete confirmation state
    @State private var itemToDelete: StorageItem?
    @State private var showDeleteConfirmation = false

    var body: some View {
        itemsList
            .navigationTitle("Items")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("item-list-new-button")

                    Button {
                        showingFilterSheet = true
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityIdentifier("item-list-filter-button")
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search items")
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.search(newValue)
            }
            .overlay {
                emptyStateOverlay
            }
            .refreshable {
                await viewModel.refreshItems()
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationStack {
                    ItemFormSheet()
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                NavigationStack {
                    ItemFilterSheet(filters: $viewModel.filters) {
                        Task {
                            await viewModel.fetchItems()
                        }
                    }
                }
            }
            .task {
                await viewModel.fetchItems()

                #if DEBUG && os(iOS)
                    // Handle injected QR code for UI testing
                    // This allows tests to simulate QR scanning without camera access
                    if let qrContent = UserDefaults.standard.string(forKey: "testQRCodeContent"),
                       let url = URL(string: qrContent)
                    {
                        UserDefaults.standard.removeObject(forKey: "testQRCodeContent")
                        await navigationManager.handleDeepLink(url)
                    }
                #endif
            }
            .task {
                // Listen for item events and refresh
                for await event in eventViewModel.stream {
                    switch event {
                    case .itemCreated, .itemUpdated, .itemDeleted,
                         .childAdded, .childRemoved:
                        isRefreshing = true
                        await viewModel.refreshItems()
                        isRefreshing = false
                    default:
                        break
                    }
                }
            }
            .onChange(of: viewModel.error != nil) { _, hasError in
                if hasError, let error = viewModel.error {
                    errorViewModel.showError(error)
                    viewModel.clearError()
                }
            }
            .overlay {
                #if os(iOS)
                    if isRefreshing {
                        LoadingOverlay(title: "Refreshing...")
                    }
                #else
                    if isRefreshing {
                        LoadingOverlay(title: "Refreshing...")
                    }
                #endif
            }
            .confirmationDialog(
                title: "Delete Item",
                message: "Are you sure you want to delete \"\(itemToDelete?.title ?? "")\"? This action cannot be undone.",
                confirmButtonTitle: "Delete",
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    if let item = itemToDelete {
                        Task {
                            do {
                                let deletedId = try await viewModel.deleteItem(item)
                                eventViewModel.emit(.itemDeleted(id: deletedId))
                            } catch {
                                errorViewModel.showError(error)
                            }
                            itemToDelete = nil
                        }
                    }
                },
                onCancel: { itemToDelete = nil }
            )
            .showViewModelError(errorViewModel)
    }

    // MARK: - Items List

    private var itemsList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedItem) {
            ForEach(viewModel.items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if shouldLoadMore(for: item) {
                        Task {
                            await viewModel.loadMoreItems()
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

    // MARK: - Empty State Overlay

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            // Initial loading state
            ContentUnavailableView {
                Label("Loading Items", systemImage: "shippingbox")
            } description: {
                ProgressView()
            }
        } else if viewModel.isSearching {
            // Searching state
            ContentUnavailableView {
                Label("Searching", systemImage: "magnifyingglass")
            } description: {
                ProgressView()
            }
        } else if viewModel.items.isEmpty {
            // Empty states - differentiate based on context
            if !viewModel.searchText.isEmpty {
                // No search results
                ContentUnavailableView.search
            } else if viewModel.filters.hasActiveFilters {
                // No filter results
                ContentUnavailableView(
                    "No Matching Items",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try adjusting your filters")
                )
            } else {
                // No items at all
                ContentUnavailableView(
                    "No Items",
                    systemImage: "shippingbox",
                    description: Text("Create your first item to get started")
                )
            }
        }
    }

    // MARK: - Pagination Helper

    private func shouldLoadMore(for item: StorageItem) -> Bool {
        guard let index = viewModel.items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        // Load more when within 3 items of the end
        let threshold = 3
        return index >= viewModel.items.count - threshold &&
            viewModel.hasNextPage &&
            !viewModel.isLoadingMore &&
            !viewModel.isLoading
    }
}

#Preview {
    @Previewable @State var selectedItem: StorageItem?
    NavigationStack {
        ItemListView(horizontalSizeClass: .compact, selectedItem: $selectedItem)
    }
}
