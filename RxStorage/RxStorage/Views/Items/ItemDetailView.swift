//
//  ItemDetailView.swift
//  RxStorage
//
//  Item detail view with QR code support
//

import SwiftUI
import RxStorageCore

/// Item detail view
struct ItemDetailView: View {
    let itemId: Int

    @State private var viewModel = ItemDetailViewModel()
    @State private var showingEditSheet = false
    @State private var showingQRSheet = false

    init(itemId: Int) {
        self.itemId = itemId
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let item = viewModel.item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        itemHeader(item)

                        Divider()

                        // Details
                        itemDetails(item)

                        // Children
                        if !viewModel.children.isEmpty {
                            Divider()
                            childrenSection
                        }
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading Item",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.item?.title ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        showingQRSheet = true
                    } label: {
                        Label("Show QR Code", systemImage: "qrcode")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item = viewModel.item {
                NavigationStack {
                    ItemFormSheet(item: item)
                }
            }
        }
        .sheet(isPresented: $showingQRSheet) {
            NavigationStack {
                QRCodeGeneratorView(itemId: itemId)
            }
        }
        .task(id: itemId) {
            await viewModel.fetchItem(id: itemId)
        }
    }

    // MARK: - Item Header

    @ViewBuilder
    private func itemHeader(_ item: StorageItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.title2)
                .fontWeight(.bold)

            if let description = item.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if item.visibility == .public {
                    Label("Public", systemImage: "globe")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                } else {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Item Details

    @ViewBuilder
    private func itemDetails(_ item: StorageItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = item.category {
                DetailRow(label: "Category", value: category.name, icon: "folder")
            }

            if let location = item.location {
                DetailRow(label: "Location", value: location.title, icon: "mappin")
            }

            if let author = item.author {
                DetailRow(label: "Author", value: author.name, icon: "person")
            }

            if let price = item.price {
                DetailRow(label: "Price", value: String(format: "%.2f", price), icon: "dollarsign.circle")
            }

            if !item.images.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Images", systemImage: "photo")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(item.images, id: \.self) { imageURL in
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Children Section

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Child Items", systemImage: "list.bullet.indent")
                .font(.headline)

            ForEach(viewModel.children) { child in
                NavigationLink(value: child) {
                    ItemRow(item: child)
                }
            }
        }
    }
}

/// Detail row component
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label(label, systemImage: icon)
                .font(.headline)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(itemId: 1)
    }
}
