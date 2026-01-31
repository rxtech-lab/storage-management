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
    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    @State private var showingError = false
    @State private var showQrCodeScanner = false

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
                    print(code)
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
                ItemFilterSheet(filters: $viewModel.filters)
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
    }

    // MARK: - Items List

    private var itemsList: some View {
        List(selection: $selectedItem) {
            ForEach(viewModel.items) { item in
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
            }
        }
        .listStyle(.inset)
    }
}

/// Item filter sheet
struct ItemFilterSheet: View {
    @Binding var filters: ItemFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Visibility") {
                Picker("Visibility", selection: $filters.visibility) {
                    Text("All").tag(nil as StorageItem.Visibility?)
                    Text("Public").tag(StorageItem.Visibility.public as StorageItem.Visibility?)
                    Text("Private").tag(StorageItem.Visibility.private as StorageItem.Visibility?)
                }
            }

            Section {
                Button("Clear Filters") {
                    filters = ItemFilters()
                }
                .disabled(filters.visibility == nil)
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedItem: StorageItem?
    NavigationStack {
        ItemListView(selectedItem: $selectedItem)
    }
}
