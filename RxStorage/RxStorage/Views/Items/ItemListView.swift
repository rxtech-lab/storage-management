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

    let horizontalSizeClass: UserInterfaceSizeClass

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedItem: Binding<StorageItem?> = .constant(nil)) {
        _selectedItem = selectedItem
        self.horizontalSizeClass = horizontalSizeClass
    }

    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    @State private var showingError = false

    #if os(iOS)
    @State private var showQrCodeScanner = false
    // QR scan state
    @State private var isLoadingFromQR = false
    @State private var qrScanError: Error?
    @State private var showQrScanError = false
    private let itemService = ItemService()
    #endif

    // Refresh state
    @State private var isRefreshing = false

    // Delete confirmation state
    @State private var itemToDelete: StorageItem?
    @State private var showDeleteConfirmation = false

    var body: some View {
        itemsList
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("item-list-new-button")
                }

                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQrCodeScanner = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("item-list-scan-button")
                }
                #endif

                ToolbarItem(placement: .secondaryAction) {
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
        #if os(iOS)
            .sheet(isPresented: $showQrCodeScanner) {
                NavigationStack {
                    QRCodeScannerView { code in
                        showQrCodeScanner = false
                        Task {
                            await handleScannedQRCode(code)
                        }
                    }
                }
            }
        #endif
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
                showingError = hasError
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    viewModel.clearError()
                }
                Button("Retry") {
                    Task {
                        await viewModel.fetchItems()
                    }
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .overlay {
                #if os(iOS)
                if isLoadingFromQR {
                    LoadingOverlay(title: "Loading item from QR code..")
                } else if isRefreshing {
                    LoadingOverlay(title: "Refreshing...")
                }
                #else
                if isRefreshing {
                    LoadingOverlay(title: "Refreshing...")
                }
                #endif
            }
        #if os(iOS)
            .alert("QR Code Error", isPresented: $showQrScanError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = qrScanError {
                    Text(error.localizedDescription)
                }
            }
        #endif
            .confirmationDialog(
                title: "Delete Item",
                message: "Are you sure you want to delete \"\(itemToDelete?.title ?? "")\"? This action cannot be undone.",
                confirmButtonTitle: "Delete",
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    if let item = itemToDelete {
                        Task {
                            if let deletedId = try? await viewModel.deleteItem(item) {
                                eventViewModel.emit(.itemDeleted(id: deletedId))
                            }
                            itemToDelete = nil
                        }
                    }
                },
                onCancel: { itemToDelete = nil }
            )
    }

    // MARK: - Items List

    @ViewBuilder
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

    #if os(iOS)

    // MARK: - QR Code Handling

    private func handleScannedQRCode(_ code: String) async {
        guard let url = URL(string: code) else {
            qrScanError = APIError.unsupportedQRCode(code)
            showQrScanError = true
            return
        }

        // Extract item ID from URL path (e.g., /preview/123)
        guard let itemIdString = url.pathComponents.last,
              let itemId = Int(itemIdString)
        else {
            qrScanError = APIError.unsupportedQRCode(code)
            showQrScanError = true
            return
        }

        // Fetch the item directly
        isLoadingFromQR = true
        defer { isLoadingFromQR = false }

        do {
            let itemDetail = try await itemService.fetchItem(id: itemId)
            selectedItem = itemDetail.toStorageItem()
        } catch {
            qrScanError = error
            showQrScanError = true
        }
    }
    #endif
}

#Preview {
    @Previewable @State var selectedItem: StorageItem?
    NavigationStack {
        ItemListView(horizontalSizeClass: .compact, selectedItem: $selectedItem)
    }
}
