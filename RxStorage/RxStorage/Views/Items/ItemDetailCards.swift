//
//  ItemDetailCards.swift
//  RxStorage
//
//  Card components for ItemDetailView
//

import RxStorageCore
import SwiftUI

// MARK: - Header Card

struct ItemDetailHeaderCard: View {
    let item: StorageItemDetail

    var body: some View {
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
}

// MARK: - Details Card

struct ItemDetailDetailsCard: View {
    let item: StorageItemDetail
    let quantity: Int
    let onStockTapped: () -> Void

    var body: some View {
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

                Button {
                    onStockTapped()
                } label: {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text("\(quantity)")
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } label: {
                        Label("Stock", systemImage: "shippingbox")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

// MARK: - Children Card

struct ItemDetailChildrenCard: View {
    let children: [StorageItem]
    let isViewOnly: Bool
    let onAddChild: () -> Void
    let onEditChild: (StorageItem) -> Void
    let onRemoveChild: (String) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Child Items", systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.leading, 16)

            if children.isEmpty {
                Text("No child items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    childRowWithSwipe(child)
                    if index < children.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }

            if !isViewOnly {
                Divider()
                    .padding(.leading, 16)
                Button {
                    onAddChild()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("Add Child Item")
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

    @ViewBuilder
    private func childRowWithSwipe(_ child: StorageItem) -> some View {
        if isViewOnly {
            childRow(child)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        } else {
            SwipeableRow(
                leadingActions: [
                    SwipeAction(title: "Edit", icon: "pencil", color: .blue) {
                        onEditChild(child)
                    },
                ],
                trailingActions: [
                    SwipeAction(title: "Remove", icon: "minus.circle", color: .red) {
                        Task { await onRemoveChild(child.id) }
                    },
                ]
            ) {
                childRow(child)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    private func childRow(_ child: StorageItem) -> some View {
        NavigationLink(value: child) {
            ItemRow(item: child)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            if !isViewOnly {
                Button {
                    onEditChild(child)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { await onRemoveChild(child.id) }
                } label: {
                    Label("Remove from Parent", systemImage: "minus.circle")
                }
            }
        }
    }
}

// MARK: - Contents Card

struct ItemDetailContentsCard: View {
    let contents: [Content]
    let totalContents: Int
    let isViewOnly: Bool
    let onSeeAll: () -> Void
    let onAddContent: () -> Void
    let onEditContent: (Content) -> Void
    let onDeleteContent: (String) async -> Void
    let onSelectContent: (Content) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onSeeAll()
            } label: {
                HStack {
                    Label("Contents", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if totalContents > 0 {
                        Text("\(totalContents)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if totalContents > contents.count {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.leading, 16)

            if contents.isEmpty {
                Text("No contents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(contents.enumerated()), id: \.element.id) { index, content in
                    contentRowWithSwipe(content)
                    if index < contents.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }

            if !isViewOnly {
                Divider()
                    .padding(.leading, 16)
                Button {
                    onAddContent()
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

    @ViewBuilder
    private func contentRowWithSwipe(_ content: Content) -> some View {
        if isViewOnly {
            contentRow(content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        } else {
            SwipeableRow(
                leadingActions: [
                    SwipeAction(title: "Edit", icon: "pencil", color: .blue) {
                        onEditContent(content)
                    },
                ],
                trailingActions: [
                    SwipeAction(title: "Delete", icon: "trash", color: .red) {
                        Task { await onDeleteContent(content.id) }
                    },
                ]
            ) {
                contentRow(content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    private func contentRow(_ content: Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let previewUrl = content.contentData.previewImageUrl,
               let url = URL(string: previewUrl)
            {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        contentTypeIcon(content)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                contentTypeIcon(content)
            }

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
            onSelectContent(content)
        }
        .contextMenu {
            if !isViewOnly {
                Button {
                    onEditContent(content)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { await onDeleteContent(content.id) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func contentTypeIcon(_ content: Content) -> some View {
        Image(systemName: content.type.icon)
            .font(.title2)
            .foregroundStyle(contentIconColor(for: content.type))
            .frame(width: 48, height: 48)
            .background(contentIconColor(for: content.type).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

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
}

// MARK: - Detail Row Component

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
