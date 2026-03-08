//
//  ItemDetailView.swift
//  RxStorage
//
//  Item detail view with QR code support
//

import RxStorageCore
import SwiftUI

// MARK: - Item Detail View

/// Item detail view
struct ItemDetailView: View {
    let itemId: String
    let isViewOnly: Bool

    @State private var viewModel = ItemDetailViewModel()
    @State private var errorViewModel = ErrorViewModel()
    @Environment(EventViewModel.self) private var eventViewModel
    @State private var showingEditSheet = false
    @State private var showingQRSheet = false
    #if os(iOS)
        @State private var nfcWriter = NFCWriter()
        @State private var isWritingNFC = false
        // Overwrite flow
        @State private var showNFCOverwriteConfirmation = false
        @State private var existingNFCContent = ""
        @State private var pendingNFCUrl = ""
        /// Lock flow
        @State private var showNFCLockSheet = false
    #endif
    @State private var showingAddChildSheet = false
    @State private var isAddingChild = false
    @State private var showingContentSheet = false
    @State private var showingContentListSheet = false
    @State private var selectedImageIndex = 0
    @State private var selectedChildForEdit: StorageItem?
    @State private var selectedChildForDetail: StorageItem?
    @State private var selectedContentForEdit: Content?
    @State private var selectedContentForDetail: Content?
    @State private var isRefreshing = false
    @State private var showingStockDetailSheet = false
    @State private var showingTagPickerSheet = false
    private let imageHeight: CGFloat = 400

    init(itemId: String, isViewOnly: Bool = false) {
        self.itemId = itemId
        self.isViewOnly = isViewOnly
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.item == nil {
                ProgressView("Loading...")
            } else if let item = viewModel.item {
                itemContent(item)
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
        .formStyle(.grouped)
        .navigationTitle(viewModel.item?.title ?? "Item")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .sheet(isPresented: $showingEditSheet) {
                if let item = viewModel.item {
                    NavigationStack {
                        ItemFormSheet(item: item.toStorageItem())
                    }
                }
            }
            .sheet(isPresented: $showingQRSheet) {
                if let item = viewModel.item {
                    NavigationStack {
                        QRCodeView(item: item)
                    }
                }
            }
            .task(id: itemId) {
                if itemId.isEmpty {
                    return
                }
                if isViewOnly {
                    // Use preview endpoint with optional auth (works for public items without token)
                    await viewModel.fetchPreviewItem(id: itemId)
                    // Skip content schemas - only needed for editing
                } else {
                    async let itemFetch: () = viewModel.fetchItem(id: itemId)
                    async let schemaFetch: () = viewModel.fetchContentSchemas()
                    _ = await (itemFetch, schemaFetch)
                    for await event in eventViewModel.stream {
                        guard !Task.isCancelled else { break }
                        await handleEvent(event)
                    }
                }
            }
        #if os(iOS)
            .confirmationDialog(
                title: "Tag Already Has Content",
                message: "This NFC tag already contains: \(existingNFCContent). Do you want to overwrite it?",
                confirmButtonTitle: "Overwrite",
                isPresented: $showNFCOverwriteConfirmation,
                onConfirm: {
                    Task { await writeToNFCWithOverwrite() }
                }
            )
            .sheet(isPresented: $showNFCLockSheet) {
                NFCLockSheet(nfcWriter: nfcWriter) {
                    showNFCLockSheet = false
                }
            }
        #endif
            .sheet(isPresented: $showingAddChildSheet) {
                if let item = viewModel.item {
                    NavigationStack {
                        AddChildSheet(
                            parentItemId: item.id,
                            existingChildIds: Set(viewModel.children.map { $0.id }),
                            isAdding: $isAddingChild,
                            onChildSelected: { childData in
                                Task { await addChild(childData.itemId) }
                            }
                        )
                    }
                }
            }
        #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
        #endif
            .sheet(isPresented: $showingContentSheet) {
                NavigationStack {
                    ContentFormSheet(
                        contentSchemas: $viewModel.contentSchemas,
                        onSubmit: { type, data in
                            Task { await createContent(type: type, data: data) }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingStockDetailSheet) {
                NavigationStack {
                    StockDetailSheet(
                        viewModel: viewModel,
                        errorViewModel: errorViewModel,
                        isViewOnly: isViewOnly
                    )
                }
            }
            .sheet(item: $selectedChildForEdit) { child in
                NavigationStack {
                    ItemFormSheet(item: child)
                }
            }
        #if os(macOS)
            .sheet(item: $selectedChildForDetail) { child in
                NavigationStack {
                    ItemDetailView(itemId: child.id, isViewOnly: isViewOnly)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    selectedChildForDetail = nil
                                }
                            }
                        }
                        .frame(minWidth: 600, minHeight: 400, idealHeight: 800)
                }
            }
        #endif
            .sheet(item: $selectedContentForEdit) { content in
                NavigationStack {
                    ContentFormSheet(
                        contentSchemas: $viewModel.contentSchemas,
                        existingContent: content,
                        onSubmit: { type, data in
                            Task { await updateContent(content.id, type: type, data: data) }
                        }
                    )
                }
            }
            .sheet(item: $selectedContentForDetail) { content in
                NavigationStack {
                    ContentDetailSheet(
                        content: content,
                        contentSchemas: $viewModel.contentSchemas,
                        onEdit: { selectedContentForEdit = content },
                        isViewOnly: isViewOnly
                    )
                }
            }
            .sheet(isPresented: $showingTagPickerSheet) {
                NavigationStack {
                    TagPickerSheet(
                        existingTagIds: Set(viewModel.tags.map { $0.id }),
                        onSelect: { tag in
                            await addTag(tag.id)
                        },
                        onDeselect: { tag in
                            await removeTag(tag.id)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingContentListSheet) {
                ContentListSheet(
                    itemId: itemId,
                    contentSchemas: $viewModel.contentSchemas,
                    isViewOnly: isViewOnly
                )
            }
            .showViewModelError(errorViewModel)
    }

    // MARK: - Item Content

    private func itemContent(_ item: StorageItemDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if !item.images.isEmpty {
                    stretchyImageCarousel(item.images)
                }

                VStack(spacing: 16) {
                    ItemDetailHeaderCard(item: item)
                    ItemDetailDetailsCard(
                        item: item,
                        quantity: viewModel.quantity,
                        onStockTapped: { showingStockDetailSheet = true }
                    )
                    ItemDetailContentsCard(
                        contents: viewModel.contents,
                        totalContents: viewModel.totalContents,
                        isViewOnly: isViewOnly,
                        onSeeAll: { showingContentListSheet = true },
                        onAddContent: { showingContentSheet = true },
                        onEditContent: { selectedContentForEdit = $0 },
                        onDeleteContent: { await deleteContent($0) },
                        onSelectContent: { selectedContentForDetail = $0 }
                    )
                    ItemDetailTagsCard(
                        tags: viewModel.tags,
                        isViewOnly: isViewOnly,
                        onAddTag: { showingTagPickerSheet = true },
                        onRemoveTag: { await removeTag($0) }
                    )
                    ItemDetailChildrenCard(
                        children: viewModel.children,
                        isViewOnly: isViewOnly,
                        onAddChild: { showingAddChildSheet = true },
                        onEditChild: { selectedChildForEdit = $0 },
                        onRemoveChild: { await removeChild($0) },
                        onSelectChild: { selectedChildForDetail = $0 }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, item.images.isEmpty ? 8 : 12)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: item.images.isEmpty ? [] : .top)
        .background(Color.systemGroupedBackground)
        .overlay {
            if isRefreshing {
                LoadingOverlay(title: "Refreshing...")
            }
        }
        .toolbar {
            if !isViewOnly {
                ToolbarItem(placement: .primaryAction) {
                    toolbarMenu(item)
                }
            }
        }
    }

    // MARK: - Toolbar Menu

    private func toolbarMenu(_ item: StorageItemDetail) -> some View {
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

            #if os(iOS)
                Button {
                    Task { await writeToNFC(previewUrl: item.previewUrl) }
                } label: {
                    Label(isWritingNFC ? "Writing..." : "Write to NFC Tag", systemImage: "wave.3.right")
                }
                .disabled(isWritingNFC)
            #endif
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: AppEvent) async {
        switch event {
        case let .itemUpdated(id) where id == itemId:
            guard !Task.isCancelled else { return }
            isRefreshing = true
            await viewModel.refresh()
            isRefreshing = false
        case let .contentCreated(iId, _) where iId == itemId,
             .contentDeleted(let iId, _) where iId == itemId:
            guard !Task.isCancelled else { return }
            isRefreshing = true
            await viewModel.refresh()
            isRefreshing = false
        case let .childAdded(pId, _) where pId == itemId,
             .childRemoved(let pId, _) where pId == itemId:
            guard !Task.isCancelled else { return }
            isRefreshing = true
            await viewModel.refresh()
            isRefreshing = false
        default:
            break
        }
    }

    // MARK: - NFC Writing

    #if os(iOS)
        private func writeToNFC(previewUrl: String) async {
            isWritingNFC = true
            pendingNFCUrl = previewUrl
            defer { isWritingNFC = false }
            do {
                try await nfcWriter.writeToNfcChip(url: previewUrl)
                showNFCLockSheet = true
            } catch let NFCWriterError.tagHasExistingContent(content) {
                existingNFCContent = content
                showNFCOverwriteConfirmation = true
            } catch NFCWriterError.cancelled {
                // User cancelled - do nothing (silent dismissal)
            } catch {
                errorViewModel.showError(error)
            }
        }

        private func writeToNFCWithOverwrite() async {
            isWritingNFC = true
            defer { isWritingNFC = false }
            do {
                try await nfcWriter.writeToNfcChip(url: pendingNFCUrl, allowOverwrite: true)
                showNFCLockSheet = true
            } catch NFCWriterError.cancelled {
                // User cancelled - do nothing
            } catch {
                errorViewModel.showError(error)
            }
        }
    #endif

    // MARK: - Image Carousel

    private func stretchyImageCarousel(_ images: [Components.Schemas.SignedImageSchema]) -> some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let stretchAmount = max(0, minY)
            let calculatedHeight = imageHeight + stretchAmount

            TabView(selection: $selectedImageIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    AsyncImage(url: URL(string: image.url)) { phase in
                        switch phase {
                        case let .success(loadedImage):
                            loadedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: calculatedHeight)
                                .clipped()
                        case .failure:
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Failed to load")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: geometry.size.width, height: calculatedHeight)
                            .background(Color.systemGray6)
                        case .empty:
                            ProgressView()
                                .frame(width: geometry.size.width, height: calculatedHeight)
                                .background(Color.systemGray6)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            #endif
            .frame(width: geometry.size.width, height: calculatedHeight)
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(height: imageHeight)
    }

    // MARK: - Child Management

    private func addChild(_ childId: String) async {
        isAddingChild = true
        defer { isAddingChild = false }
        do {
            let (parentId, childId) = try await viewModel.addChildById(childId)
            eventViewModel.emit(.childAdded(parentId: parentId, childId: childId))
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func removeChild(_ childId: String) async {
        do {
            let (parentId, childId) = try await viewModel.removeChildById(childId)
            eventViewModel.emit(.childRemoved(parentId: parentId, childId: childId))
        } catch {
            errorViewModel.showError(error)
        }
    }

    // MARK: - Tag Management

    private func addTag(_ tagId: String) async {
        do {
            try await viewModel.addTag(tagId)
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func removeTag(_ tagId: String) async {
        do {
            try await viewModel.removeTag(tagId)
        } catch {
            errorViewModel.showError(error)
        }
    }

    // MARK: - Content Management

    private func createContent(type: ContentType, data: [String: AnyCodable]) async {
        do {
            let (itemId, contentId) = try await viewModel.createContent(type: type, formData: data)
            eventViewModel.emit(.contentCreated(itemId: itemId, contentId: contentId))
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func deleteContent(_ id: String) async {
        do {
            let (itemId, contentId) = try await viewModel.deleteContent(id: id)
            eventViewModel.emit(.contentDeleted(itemId: itemId, contentId: contentId))
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func updateContent(_ id: String, type: ContentType, data: [String: AnyCodable]) async {
        do {
            try await viewModel.updateContent(id: id, type: type, formData: data)
            await viewModel.refresh()
        } catch {
            errorViewModel.showError(error)
        }
    }
}
