//
//  ContentSectionView.swift
//  RxStorage
//
//  View for displaying contents attached to an item
//

import RxStorageCore
import SwiftUI

/// Section view for displaying item contents
struct ContentSectionView: View {
    let contents: [Content]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Contents", systemImage: "doc.on.doc")
                .font(.headline)

            ForEach(contents) { content in
                ContentRowView(content: content)
            }
        }
    }
}

/// Row view for a single content item
struct ContentRowView: View {
    let content: Content

    private var iconColor: Color {
        switch content.type {
        case .file:
            return .blue
        case .image:
            return .green
        case .video:
            return .purple
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.type.icon)
                .font(.title2)
                .foregroundStyle(iconColor)
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentSectionView(contents: [
        Content(
            id: 1,
            itemId: 1,
            type: .file,
            data: ContentData(
                title: "Document.pdf",
                description: "Important document",
                mimeType: "application/pdf",
                size: 1_024_000
            ),
            createdAt: Date(),
            updatedAt: Date()
        ),
        Content(
            id: 2,
            itemId: 1,
            type: .image,
            data: ContentData(
                title: "Photo.jpg",
                mimeType: "image/jpeg",
                size: 2_048_000
            ),
            createdAt: Date(),
            updatedAt: Date()
        ),
        Content(
            id: 3,
            itemId: 1,
            type: .video,
            data: ContentData(
                title: "Video.mp4",
                mimeType: "video/mp4",
                size: 10_240_000,
                videoLength: 120
            ),
            createdAt: Date(),
            updatedAt: Date()
        ),
    ])
    .padding()
}
