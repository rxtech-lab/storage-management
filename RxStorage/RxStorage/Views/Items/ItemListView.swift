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

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(selectedItem: Binding<StorageItem?> = .constant(nil)) {
        _selectedItem = selectedItem
    }

    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    @State private var showingError = false
    @State private var showQrCodeScanner = false

    // QR scan state
    @State private var isLoadingFromQR = false
    @State private var qrScanError: Error?
    @State private var showQrScanError = false
    private let itemService = ItemService()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("Loading items...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "shippingbox",
                    description: Text("Create your first item to get started")
                )
            } else {
                itemsList
            }
        }
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Item", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showQrCodeScanner = true
                } label: {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search items")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .refreshable {
            await viewModel.refreshItems()
        }
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
            if isLoadingFromQR {
                LoadingOverlay(title: "Loading item from QR code..")
            }
        }
        .alert("QR Code Error", isPresented: $showQrScanError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = qrScanError {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Items List

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var itemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                // On iPhone (compact), use NavigationLink for push navigation
                // On iPad (regular), use Button to set selection for split view
                if horizontalSizeClass == .compact {
                    NavigationLink(value: item) {
                        ItemRow(item: item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteItem(item)
                            }
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
                } else {
                    Button {
                        selectedItem = item
                    } label: {
                        ItemRow(item: item)
                    }
                    .listRowBackground(selectedItem?.id == item.id ? Color.accentColor.opacity(0.2) : nil)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteItem(item)
                            }
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
        .listStyle(.automatic)
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

    // MARK: - QR Code Handling

    private func handleScannedQRCode(_ code: String) async {
        guard let url = URL(string: code) else {
            qrScanError = APIError.unsupportedQRCode(code)
            showQrScanError = true
            return
        }

        isLoadingFromQR = true
        defer { isLoadingFromQR = false }

        do {
            let item = try await itemService.fetchItemFromURL(url)
            selectedItem = item
        } catch {
            qrScanError = error
            showQrScanError = true
        }
    }
}

/// Item filter sheet
struct ItemFilterSheet: View {
    @Binding var filters: ItemFilters
    let onApply: () -> Void

    @State private var viewModel: ItemFilterViewModel
    @Environment(\.dismiss) private var dismiss

    init(filters: Binding<ItemFilters>, onApply: @escaping () -> Void) {
        self._filters = filters
        self.onApply = onApply
        self._viewModel = State(initialValue: ItemFilterViewModel(initialFilters: filters.wrappedValue))
    }

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading filters...")
                        Spacer()
                    }
                }
            } else {
                // Visibility Section
                Section("Visibility") {
                    Picker("Visibility", selection: $viewModel.selectedVisibility) {
                        Text("All").tag(nil as StorageItem.Visibility?)
                        Text("Public").tag(StorageItem.Visibility.public as StorageItem.Visibility?)
                        Text("Private").tag(StorageItem.Visibility.private as StorageItem.Visibility?)
                    }
                }

                // Category Section
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategoryId) {
                        Text("All Categories").tag(nil as Int?)
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(category.id as Int?)
                        }
                    }
                }

                // Location Section
                Section("Location") {
                    Picker("Location", selection: $viewModel.selectedLocationId) {
                        Text("All Locations").tag(nil as Int?)
                        ForEach(viewModel.locations) { location in
                            Text(location.title).tag(location.id as Int?)
                        }
                    }
                }

                // Author Section
                Section("Author") {
                    Picker("Author", selection: $viewModel.selectedAuthorId) {
                        Text("All Authors").tag(nil as Int?)
                        ForEach(viewModel.authors) { author in
                            Text(author.name).tag(author.id as Int?)
                        }
                    }
                }

                // Clear Filters Button
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        viewModel.clearFilters()
                    }
                    .disabled(!viewModel.hasActiveFilters)
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    filters = viewModel.buildFilters()
                    onApply()
                    dismiss()
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadFilterOptions()
        }
    }
}

#Preview {
    @Previewable @State var selectedItem: StorageItem?
    NavigationStack {
        ItemListView(selectedItem: $selectedItem)
    }
}
