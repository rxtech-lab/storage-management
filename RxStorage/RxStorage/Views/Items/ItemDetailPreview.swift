//
//  ItemDetailPreview.swift
//  RxStorage
//
//  Preview helpers and sample data for ItemDetailView
//

import OpenAPIRuntime
import RxStorageCore
import SwiftUI

// MARK: - Previews

#Preview("Full Mode") {
    NavigationStack {
        ItemDetailPreviewContainer(isViewOnly: false)
    }
    .environment(EventViewModel())
}

#Preview("View Only Mode") {
    NavigationStack {
        ItemDetailPreviewContainer(isViewOnly: true)
    }
    .environment(EventViewModel())
}

// MARK: - Preview Helper

struct ItemDetailPreviewContainer: View {
    let isViewOnly: Bool

    var body: some View {
        ItemDetailPreviewView(isViewOnly: isViewOnly)
    }
}

struct ItemDetailPreviewView: View {
    let isViewOnly: Bool
    @State private var sampleContents: [Content] = PreviewSampleData.sampleContents
    @State private var showingEditSheet = false
    @State private var showingQRSheet = false
    @State private var showingAddChildSheet = false
    @State private var showingContentSheet = false
    @State private var selectedContentForDetail: Content?
    @State private var showingStockDetailSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    previewHeaderCard
                    previewDetailsCard
                    previewContentsCard
                    previewChildrenCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.systemGroupedBackground)
        .navigationTitle("Sample Item")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
    }

    // MARK: - Preview Cards

    private var previewHeaderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sample Storage Item")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Label("Public", systemImage: "globe")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            }
            Text("This is a sample item for preview purposes. It demonstrates how the detail view looks with content.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var previewDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 12) {
                LabeledContent {
                    Text("Electronics")
                } label: {
                    Label("Category", systemImage: "folder")
                }

                LabeledContent {
                    Text("Office")
                } label: {
                    Label("Location", systemImage: "mappin")
                }

                LabeledContent {
                    Text("John Doe")
                } label: {
                    Label("Author", systemImage: "person")
                }

                LabeledContent {
                    Text(99.99, format: .currency(code: "USD"))
                } label: {
                    Label("Price", systemImage: "dollarsign.circle")
                }

                Button {
                    showingStockDetailSheet = true
                } label: {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text("15")
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

    private var previewContentsCard: some View {
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

            List {
                ForEach(sampleContents) { content in
                    previewContentRow(content)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(minHeight: CGFloat(sampleContents.count) * 72)

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

    private func previewContentRow(_ content: Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.type.icon)
                .font(.title2)
                .foregroundStyle(previewContentIconColor(for: content.type))
                .frame(width: 48, height: 48)
                .background(previewContentIconColor(for: content.type).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

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
    }

    private func previewContentIconColor(for type: ContentType) -> Color {
        switch type {
        case .file:
            return .blue
        case .image:
            return .green
        case .video:
            return .purple
        }
    }

    private var previewChildrenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Child Items", systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            Text("No child items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

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
}

// MARK: - Preview Sample Data

enum PreviewSampleData {
    static var sampleContents: [Content] {
        let now = Date()
        return [
            makeContent(id: "1", type: .file, title: "User Manual", description: "Complete user manual in PDF format", mimeType: "application/pdf", size: 2_500_000, createdAt: now),
            makeContent(id: "2", type: .image, title: "Product Photo", description: "Front view of the product", mimeType: "image/jpeg", size: 1_200_000, createdAt: now),
            makeContent(id: "3", type: .video, title: "Setup Tutorial", description: "Step by step setup guide", mimeType: "video/mp4", size: 50_000_000, videoLength: 320, createdAt: now),
            makeContent(id: "4", type: .file, title: "Warranty Card", description: "2-year warranty information", mimeType: "application/pdf", size: 500_000, createdAt: now),
            makeContent(id: "5", type: .image, title: "Side View", description: "Product photographed from the side", mimeType: "image/png", size: 800_000, createdAt: now),
            makeContent(id: "6", type: .image, title: "Back Panel", description: "Shows all connection ports", mimeType: "image/jpeg", size: 950_000, createdAt: now),
            makeContent(id: "7", type: .video, title: "Unboxing Video", description: "What's inside the box", mimeType: "video/mp4", size: 35_000_000, videoLength: 180, createdAt: now),
            makeContent(id: "8", type: .file, title: "Quick Start Guide", description: "Getting started in 5 minutes", mimeType: "application/pdf", size: 750_000, createdAt: now),
            makeContent(id: "9", type: .image, title: "Dimensions Diagram", description: "Technical dimensions illustration", mimeType: "image/svg+xml", size: 150_000, createdAt: now),
            makeContent(id: "10", type: .file, title: "Specifications Sheet", description: "Complete technical specifications", mimeType: "application/pdf", size: 1_100_000, createdAt: now),
        ]
    }

    // swiftlint:disable force_try
    private static func makeContent(
        id: String,
        type: ContentType,
        title: String,
        description: String,
        mimeType: String,
        size: Int,
        videoLength: Int? = nil,
        createdAt: Date
    ) -> Content {
        var additionalProperties: [String: OpenAPIValueContainer] = [
            "title": try! .init(unvalidatedValue: title),
            "description": try! .init(unvalidatedValue: description),
            "mime_type": try! .init(unvalidatedValue: mimeType),
            "size": try! .init(unvalidatedValue: size),
        ]

        if let videoLength = videoLength {
            additionalProperties["video_length"] = try! .init(unvalidatedValue: videoLength)
        }

        return Content(
            id: id,
            itemId: "preview-item",
            _type: type,
            data: Content.dataPayload(additionalProperties: additionalProperties),
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
    // swiftlint:enable force_try
}
