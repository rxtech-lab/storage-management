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
            // Thumbnail or icon
            if let previewUrl = content.contentData.previewImageUrl,
               let url = URL(string: previewUrl)
            {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: content.type.icon)
                            .font(.title2)
                            .foregroundStyle(iconColor)
                            .frame(width: 48, height: 48)
                            .background(iconColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: content.type.icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 48, height: 48)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .padding(.vertical, 4)
    }
}

// Preview disabled - generated types have different initializers
// TODO: Update preview to use generated Content types
