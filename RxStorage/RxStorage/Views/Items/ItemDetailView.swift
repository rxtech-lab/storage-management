//
//  ItemDetailView.swift
//  RxStorage
//
//  Item detail view with QR code support
//

import RxStorageCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Platform Colors

private extension Color {
    static var systemGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondarySystemGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var systemGray6: Color {
        #if os(iOS)
        Color(UIColor.systemGray6)
        #else
        Color(nsColor: .systemGray)
        #endif
    }
}

// MARK: - Item Detail View

/// Item detail view
struct ItemDetailView: View {
    let itemId: Int
    let isViewOnly: Bool

    @State private var viewModel = ItemDetailViewModel()
    @Environment(EventViewModel.self) private var eventViewModel
    @State private var showingEditSheet = false
    @State private var showingQRSheet = false
    #if os(iOS)
    @State private var nfcWriter = NFCWriter()
    @State private var isWritingNFC = false
    @State private var showNFCError = false
    @State private var nfcError: Error?
    @State private var showNFCSuccess = false
    #endif
    @State private var showingAddChildSheet = false
    @State private var isAddingChild = false
    @State private var addChildError: Error?
    @State private var showAddChildError = false
    @State private var removeChildError: Error?
    @State private var showRemoveChildError = false
    @State private var showingContentSheet = false
    @State private var contentError: Error?
    @State private var showContentError = false
    @State private var selectedImageIndex = 0
    @State private var selectedChildForEdit: StorageItem?
    @State private var selectedContentForEdit: Content?
    @State private var selectedContentForDetail: Content?
    @State private var isRefreshing = false
    private let imageHeight: CGFloat = 400

    init(itemId: Int, isViewOnly: Bool = false) {
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
                        QRCodeView(urlString: item.previewUrl)
                    }
                }
            }
            .task(id: itemId) {
                await viewModel.fetchItem(id: itemId)
                await viewModel.fetchContentSchemas()
                for await event in eventViewModel.stream {
                    guard !Task.isCancelled else { break }
                    await handleEvent(event)
                }
            }
        #if os(iOS)
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
        #endif
            .sheet(isPresented: $showingAddChildSheet) {
                if let item = viewModel.item {
                    NavigationStack {
                        AddChildSheet(
                            parentItemId: item.id,
                            existingChildIds: Set(viewModel.children.map { $0.id }),
                            isAdding: $isAddingChild,
                            onChildSelected: { childData in
                                if let childId = Int(childData.itemId) {
                                    Task { await addChild(childId) }
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
                            Task { await createContent(type: type, data: data) }
                        }
                    )
                }
            }
            .alert("Content Error", isPresented: $showContentError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(contentError?.localizedDescription ?? "An error occurred.")
            }
            .sheet(item: $selectedChildForEdit) { child in
                NavigationStack {
                    ItemFormSheet(item: child)
                }
            }
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
    }

    // MARK: - Item Content

    @ViewBuilder
    private func itemContent(_ item: StorageItemDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if !item.images.isEmpty {
                    stretchyImageCarousel(item.images)
                }

                VStack(spacing: 16) {
                    headerCard(item)
                    detailsCard(item)
                    contentsCard
                    childrenCard
                }
                .padding(.horizontal, 16)
                .padding(.top, item.images.isEmpty ? 16 : 8)
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

    @ViewBuilder
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
        case .itemUpdated(let id) where id == itemId:
            guard !Task.isCancelled else { return }
            isRefreshing = true
            await viewModel.refresh()
            isRefreshing = false
        case .contentCreated(let iId, _) where iId == itemId,
             .contentDeleted(let iId, _) where iId == itemId:
            guard !Task.isCancelled else { return }
            isRefreshing = true
            await viewModel.refresh()
            isRefreshing = false
        case .childAdded(let pId, _) where pId == itemId,
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
        defer { isWritingNFC = false }
        do {
            try await nfcWriter.writeToNfcChip(url: previewUrl)
            showNFCSuccess = true
        } catch let error as NFCWriterError where error == .cancelled {
            // User cancelled - do nothing (silent dismissal)
        } catch {
            nfcError = error
            showNFCError = true
        }
    }
    #endif

    // MARK: - Image Carousel

    @ViewBuilder
    private func stretchyImageCarousel(_ images: [Components.Schemas.SignedImageSchema]) -> some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let stretchAmount = max(0, minY)
            let calculatedHeight = imageHeight + stretchAmount

            TabView(selection: $selectedImageIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    AsyncImage(url: URL(string: image.url)) { phase in
                        switch phase {
                        case .success(let loadedImage):
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

    // MARK: - Header Card

    @ViewBuilder
    private func headerCard(_ item: StorageItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("item-detail-title")
                Spacer()
                if item.visibility == .publicAccess {
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

            if let description = item.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Details Card

    @ViewBuilder
    private func detailsCard(_ item: StorageItemDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 12) {
                if let category = item.category {
                    LabeledContent {
                        Text(category.value1.name)
                    } label: {
                        Label("Category", systemImage: "folder")
                    }
                }

                if let location = item.location {
                    LabeledContent {
                        Text(location.value1.title)
                    } label: {
                        Label("Location", systemImage: "mappin")
                    }
                }

                if let author = item.author {
                    LabeledContent {
                        Text(author.value1.name)
                    } label: {
                        Label("Author", systemImage: "person")
                    }
                }

                if let price = item.price {
                    LabeledContent {
                        Text(price, format: .currency(code: "USD"))
                    } label: {
                        Label("Price", systemImage: "dollarsign.circle")
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Children Card

    private var childrenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Child Items", systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            if viewModel.children.isEmpty {
                Text("No child items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(viewModel.children.enumerated()), id: \.element.id) { index, child in
                    childRowWithActions(child)
                    if index < viewModel.children.count - 1 {
                        Divider()
                    }
                }
            }

            if !isViewOnly {
                Divider()
                Button {
                    showingAddChildSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("Add Child Item")
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func childRowWithActions(_ child: StorageItem) -> some View {
        HStack {
            NavigationLink(value: child) {
                ItemRow(item: child)
            }
            .buttonStyle(.plain)

            if !isViewOnly {
                HStack(spacing: 12) {
                    Button {
                        selectedChildForEdit = child
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await removeChild(child.id) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            if !isViewOnly {
                Button {
                    selectedChildForEdit = child
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { await removeChild(child.id) }
                } label: {
                    Label("Remove from Parent", systemImage: "minus.circle")
                }
            }
        }
    }

    // MARK: - Child Management

    private func addChild(_ childId: Int) async {
        isAddingChild = true
        defer { isAddingChild = false }
        do {
            let (parentId, childId) = try await viewModel.addChildById(childId)
            eventViewModel.emit(.childAdded(parentId: parentId, childId: childId))
        } catch {
            addChildError = error
            showAddChildError = true
        }
    }

    private func removeChild(_ childId: Int) async {
        do {
            let (parentId, childId) = try await viewModel.removeChildById(childId)
            eventViewModel.emit(.childRemoved(parentId: parentId, childId: childId))
        } catch {
            removeChildError = error
            showRemoveChildError = true
        }
    }

    // MARK: - Contents Card

    private var contentsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Contents", systemImage: "doc.on.doc")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.leading, 16)

            if viewModel.contents.isEmpty {
                Text("No contents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                List {
                    ForEach(viewModel.contents) { content in
                        contentRow(content)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if !isViewOnly {
                                    Button {
                                        selectedContentForEdit = content
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isViewOnly {
                                    Button(role: .destructive) {
                                        Task { await deleteContent(content.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(viewModel.contents.count) * 80)
            }

            if !isViewOnly {
                Divider()
                    .padding(.leading, 16)
                Button {
                    showingContentSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("Add Content")
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Content Row

    @ViewBuilder
    private func contentRow(_ content: Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.type.icon)
                .font(.title2)
                .foregroundStyle(contentIconColor(for: content.type))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(content.contentData.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description = content.contentData.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let mimeType = content.contentData.mimeType {
                        Text(mimeType)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let size = content.contentData.formattedSize {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let duration = content.contentData.formattedVideoLength {
                        Label(duration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedContentForDetail = content
        }
        .contextMenu {
            if !isViewOnly {
                Button {
                    selectedContentForEdit = content
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { await deleteContent(content.id) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Content Management

    private func contentIconColor(for type: ContentType) -> Color {
        switch type {
        case .file:
            return .blue
        case .image:
            return .green
        case .video:
            return .purple
        }
    }

    private func createContent(type: ContentType, data: [String: AnyCodable]) async {
        do {
            let (itemId, contentId) = try await viewModel.createContent(type: type, formData: data)
            eventViewModel.emit(.contentCreated(itemId: itemId, contentId: contentId))
        } catch {
            contentError = error
            showContentError = true
        }
    }

    private func deleteContent(_ id: Int) async {
        do {
            let (itemId, contentId) = try await viewModel.deleteContent(id: id)
            eventViewModel.emit(.contentDeleted(itemId: itemId, contentId: contentId))
        } catch {
            contentError = error
            showContentError = true
        }
    }

    private func updateContent(_ id: Int, type: ContentType, data: [String: AnyCodable]) async {
        do {
            try await viewModel.updateContent(id: id, type: type, formData: data)
            await viewModel.refresh()
        } catch {
            contentError = error
            showContentError = true
        }
    }
}

// MARK: - Card Style Extension

private extension View {
    func cardStyle() -> some View {
        padding(16)
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Detail Row Component

/// Detail row component (shared with other views)
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

// MARK: - Previews

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
