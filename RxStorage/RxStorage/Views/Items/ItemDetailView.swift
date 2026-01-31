//
//  ItemDetailView.swift
//  RxStorage
//
//  Item detail view with QR code support
//

import RxStorageCore
import SwiftUI

/// Item detail view
struct ItemDetailView: View {
    let itemId: Int
    let isViewOnly: Bool

    @State private var viewModel = ItemDetailViewModel()
    @State private var showingEditSheet = false
    @State private var showingQRSheet = false
    @State private var nfcWriter = NFCWriter()
    @State private var isWritingNFC = false
    @State private var showNFCError = false
    @State private var nfcError: Error?
    @State private var showNFCSuccess = false
    @State private var showingAddChildSheet = false
    @State private var isAddingChild = false
    @State private var addChildError: Error?
    @State private var showAddChildError = false
    @State private var removeChildError: Error?
    @State private var showRemoveChildError = false
    @State private var showingContentSheet = false
    @State private var contentError: Error?
    @State private var showContentError = false

    init(itemId: Int, isViewOnly: Bool = false) {
        self.itemId = itemId
        self.isViewOnly = isViewOnly
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

                        // Contents
                        Divider()
                        contentsSection

                        // Children
                        Divider()
                        childrenSection
                    }
                    .padding()
                }
                .toolbar {
                    if !isViewOnly {
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

                                Button {
                                    Task {
                                        await writeToNFC(previewUrl: item.previewUrl)
                                    }
                                } label: {
                                    Label(isWritingNFC ? "Writing..." : "Write to NFC Tag", systemImage: "wave.3.right")
                                }
                                .disabled(isWritingNFC)
                            } label: {
                                Label("More", systemImage: "ellipsis.circle")
                            }
                        }
                    }
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
        .sheet(isPresented: $showingEditSheet) {
            if let item = viewModel.item {
                NavigationStack {
                    ItemFormSheet(item: item)
                }
            }
        }
        .sheet(isPresented: $showingQRSheet) {
            if let item = viewModel.item {
                NavigationStack {
                    QRCodeView(urlString: item.previewUrl)
                }
            }
        }
        .task(id: itemId) {
            await viewModel.fetchItem(id: itemId)
            await viewModel.fetchContentSchemas()
        }
        .alert("NFC Write Successful", isPresented: $showNFCSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The URL has been written to the NFC tag.")
        }
        .alert("NFC Write Error", isPresented: $showNFCError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nfcError?.localizedDescription ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showingAddChildSheet) {
            if let item = viewModel.item {
                NavigationStack {
                    AddChildSheet(
                        parentItemId: item.id,
                        existingChildIds: Set(viewModel.children.map { $0.id }),
                        isAdding: $isAddingChild,
                        onChildSelected: { childData in
                            if let childId = Int(childData.itemId) {
                                Task {
                                    await addChild(childId)
                                }
                            }
                        }
                    )
                }
            }
        }
        .alert("Error Adding Child", isPresented: $showAddChildError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addChildError?.localizedDescription ?? "An error occurred while adding the child item.")
        }
        .alert("Error Removing Child", isPresented: $showRemoveChildError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(removeChildError?.localizedDescription ?? "An error occurred while removing the child item.")
        }
        .sheet(isPresented: $showingContentSheet) {
            NavigationStack {
                ContentFormSheet(
                    contentSchemas: $viewModel.contentSchemas,
                    onSubmit: { type, data in
                        Task {
                            await createContent(type: type, data: data)
                        }
                    }
                )
            }
        }
        .alert("Content Error", isPresented: $showContentError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contentError?.localizedDescription ?? "An error occurred.")
        }
    }

    // MARK: - NFC Writing

    private func writeToNFC(previewUrl: String) async {
        isWritingNFC = true
        defer { isWritingNFC = false }
        do {
            try await nfcWriter.writeToNfcChip(url: previewUrl)
            showNFCSuccess = true
        } catch {
            nfcError = error
            showNFCError = true
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
            HStack {
                Label("Child Items", systemImage: "list.bullet.indent")
                    .font(.headline)

                Spacer()

                if !isViewOnly {
                    Button {
                        showingAddChildSheet = true
                    } label: {
                        Label("Add Child", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }

            if viewModel.children.isEmpty {
                Text("No child items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.children) { child in
                    HStack {
                        NavigationLink(value: child) {
                            ItemRow(item: child)
                        }

                        Spacer()

                        if !isViewOnly {
                            Button(role: .destructive) {
                                // Capture child ID synchronously before entering async context
                                let childId = child.id
                                Task {
                                    await removeChild(childId)
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Child Management

    private func addChild(_ childId: Int) async {
        isAddingChild = true
        defer { isAddingChild = false }
        do {
            try await viewModel.addChildById(childId)
        } catch {
            addChildError = error
            showAddChildError = true
        }
    }

    private func removeChild(_ childId: Int) async {
        do {
            try await viewModel.removeChildById(childId)
        } catch {
            removeChildError = error
            showRemoveChildError = true
        }
    }

    // MARK: - Contents Section

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Contents", systemImage: "doc.on.doc")
                    .font(.headline)

                Spacer()

                if !isViewOnly {
                    Button {
                        showingContentSheet = true
                    } label: {
                        Label("Add Content", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }

            if viewModel.contents.isEmpty {
                Text("No contents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.contents) { content in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: content.type.icon)
                            .font(.title2)
                            .foregroundStyle(contentIconColor(for: content.type))
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(content.data.title ?? "Untitled")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let description = content.data.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            HStack(spacing: 8) {
                                if let mimeType = content.data.mimeType {
                                    Text(mimeType)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                if let size = content.data.formattedSize {
                                    Text(size)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                if let duration = content.data.formattedVideoLength {
                                    Label(duration, systemImage: "clock")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }

                        Spacer()

                        if !isViewOnly {
                            Button(role: .destructive) {
                                Task {
                                    await deleteContent(content.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Content Management

    private func contentIconColor(for type: Content.ContentType) -> Color {
        switch type {
        case .file:
            return .blue
        case .image:
            return .green
        case .video:
            return .purple
        }
    }

    private func createContent(type: Content.ContentType, data: [String: AnyCodable]) async {
        do {
            try await viewModel.createContent(type: type, formData: data)
        } catch {
            contentError = error
            showContentError = true
        }
    }

    private func deleteContent(_ id: Int) async {
        do {
            try await viewModel.deleteContent(id: id)
        } catch {
            contentError = error
            showContentError = true
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

#Preview("Full Mode") {
    NavigationStack {
        ItemDetailView(itemId: 1)
    }
}

#Preview("View Only Mode") {
    NavigationStack {
        ItemDetailView(itemId: 1, isViewOnly: true)
    }
}
