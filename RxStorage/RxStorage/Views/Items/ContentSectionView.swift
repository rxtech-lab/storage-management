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
