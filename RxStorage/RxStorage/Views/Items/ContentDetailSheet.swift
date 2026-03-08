//
//  ContentDetailSheet.swift
//  RxStorage
//
//  Detail sheet for viewing content with media carousel and metadata
//

import AVKit
import JSONSchema
import JSONSchemaForm
import OpenAPIRuntime
import RxStorageCore
import SwiftUI

// MARK: - Platform Colors

private extension Color {
    static var sheetSystemGroupedBackground: Color {
        #if os(iOS)
            Color(UIColor.systemGroupedBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var sheetSecondaryGroupedBackground: Color {
        #if os(iOS)
            Color(UIColor.secondarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var sheetSystemGray6: Color {
        #if os(iOS)
            Color(UIColor.systemGray6)
        #else
            Color(nsColor: .systemGray)
        #endif
    }
}

/// Content detail sheet with carousel media viewer
struct ContentDetailSheet: View {
    let content: Content
    @Binding var contentSchemas: [ContentSchema]
    let onEdit: () -> Void
    let isViewOnly: Bool

    @State private var formData: FormData = .object(properties: [:])
    @State private var selectedMediaIndex = 0
    @State private var fullscreenMediaItem: MediaItem?
    @Environment(\.dismiss) private var dismiss

    private let mediaHeight: CGFloat = 350

    /// Get the schema for this content's type
    private var selectedSchema: ContentSchema? {
        contentSchemas.first(where: { $0._type.rawValue == content.type.rawValue })
    }

    /// Color for content type icon
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

    /// Collect media URLs for the carousel
    private var mediaItems: [MediaItem] {
        var items: [MediaItem] = []

        // Add preview image
        if let previewUrl = content.contentData.previewImageUrl,
           let url = URL(string: previewUrl)
        {
            items.append(.image(url))
        }

        // Add preview video
        if let previewVideoUrl = content.contentData.previewVideoUrl,
           let url = URL(string: previewVideoUrl)
        {
            items.append(.video(url))
        }

        // If no preview but file_path is an image, use that
        if items.isEmpty,
           content.type == .image,
           let filePath = content.contentData.filePath,
           let url = URL(string: filePath)
        {
            items.append(.image(url))
        }

        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !mediaItems.isEmpty {
                    mediaCarousel
                }

                VStack(spacing: 16) {
                    headerCard
                    detailsCard
                    schemaDataCard
                    metadataCard
                }
                .padding(.horizontal, 16)
                .padding(.top, mediaItems.isEmpty ? 8 : 12)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: mediaItems.isEmpty ? [] : .top)
        .background(Color.sheetSystemGroupedBackground)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { dismiss() } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    if !isViewOnly {
                        Button {
                            dismiss()
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }
        #else
            .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    if !isViewOnly {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Edit") {
                                dismiss()
                                onEdit()
                            }
                        }
                    }
                }
        #endif
                .onAppear {
                    formData = contentDataToFormData(content.contentData)
                }
        #if os(iOS)
                .fullScreenCover(item: $fullscreenMediaItem) { mediaItem in
                    FullscreenMediaViewer(mediaItem: mediaItem) {
                        fullscreenMediaItem = nil
                    }
                }
        #else
                .sheet(item: $fullscreenMediaItem) { mediaItem in
                    FullscreenMediaViewer(mediaItem: mediaItem) {
                        fullscreenMediaItem = nil
                    }
                    .frame(minWidth: 800, minHeight: 600)
                }
        #endif
    }

    // MARK: - Media Carousel

    private var mediaCarousel: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let stretchAmount = max(0, minY)
            let calculatedHeight = mediaHeight + stretchAmount

            MediaCarousel(items: mediaItems, selectedIndex: $selectedMediaIndex) { item in
                switch item {
                case let .image(url):
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(loadedImage):
                            loadedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: calculatedHeight)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    fullscreenMediaItem = item
                                }
                        case .failure:
                            mediaPlaceholder(icon: "photo", text: "Failed to load")
                                .frame(width: geometry.size.width, height: calculatedHeight)
                        case .empty:
                            ProgressView()
                                .frame(width: geometry.size.width, height: calculatedHeight)
                                .background(Color.sheetSystemGray6)
                        @unknown default:
                            EmptyView()
                        }
                    }

                case let .video(url):
                    ZStack {
                        // Video thumbnail or preview
                        CachedAsyncImage(url: videoThumbnailURL(for: url)) { phase in
                            switch phase {
                            case let .success(loadedImage):
                                loadedImage
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                Rectangle()
                                    .fill(Color.sheetSystemGray6)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: geometry.size.width, height: calculatedHeight)
                        .clipped()

                        // Play button overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fullscreenMediaItem = item
                    }
                }
            }
            .frame(width: geometry.size.width, height: calculatedHeight)
            .offset(y: minY > 0 ? -minY : 0)
            #if os(macOS)
                .padding(.top, 10)
            #endif
        }
        .frame(height: mediaHeight)
    }

    /// Get thumbnail URL for video (uses preview image if available)
    private func videoThumbnailURL(for _: URL) -> URL? {
        // Try to use preview image URL if available
        if let previewUrl = content.contentData.previewImageUrl,
           let url = URL(string: previewUrl)
        {
            return url
        }
        return nil
    }

    private func mediaPlaceholder(icon: String, text: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sheetSystemGray6)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.contentData.title ?? "Untitled")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Label(content.type.displayName, systemImage: content.type.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(iconColor.opacity(0.2))
                    .foregroundStyle(iconColor)
                    .cornerRadius(4)
            }

            if let description = content.contentData.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.sheetSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 12) {
                if let mimeType = content.contentData.mimeType {
                    LabeledContent {
                        Text(mimeType)
                    } label: {
                        Label("Type", systemImage: "doc")
                    }
                }

                if let size = content.contentData.formattedSize {
                    LabeledContent {
                        Text(size)
                    } label: {
                        Label("Size", systemImage: "internaldrive")
                    }
                }

                if let duration = content.contentData.formattedVideoLength {
                    LabeledContent {
                        Text(duration)
                    } label: {
                        Label("Duration", systemImage: "clock")
                    }
                }
            }
        }
        .padding(16)
        .background(Color.sheetSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Schema Data Card

    @ViewBuilder
    private var schemaDataCard: some View {
        if let schema = selectedSchema,
           let jsonSchema = parseSchema(from: schema.schema)
        {
            VStack(alignment: .leading, spacing: 12) {
                Label("Content Data", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Divider()

                JSONSchemaForm(
                    schema: jsonSchema,
                    formData: $formData,
                    showSubmitButton: false,
                    readonly: true
                )
            }
            .padding(16)
            .background(Color.sheetSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Metadata", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 12) {
                LabeledContent {
                    Text(content.createdAt, style: .date)
                } label: {
                    Label("Created", systemImage: "calendar.badge.plus")
                }
                LabeledContent {
                    Text(content.updatedAt, style: .date)
                } label: {
                    Label("Updated", systemImage: "calendar.badge.clock")
                }
            }
        }
        .padding(16)
        .background(Color.sheetSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Methods

    /// Parse schema from schemaPayload (additionalProperties)
    private func parseSchema(from schemaPayload: ContentSchema.schemaPayload) -> JSONSchema? {
        let dict = schemaPayload.additionalProperties.compactMapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    /// Parse schema dictionary to JSONSchema
    private func parseSchema(from dict: [String: RxStorageCore.AnyCodable]) -> JSONSchema? {
        let unwrappedDict = dict.mapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: unwrappedDict) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    /// Convert ContentData to FormData for display
    private func contentDataToFormData(_ data: ContentData) -> FormData {
        var properties: [String: FormData] = [:]

        if let title = data.title {
            properties["title"] = .string(title)
        }
        if let description = data.description {
            properties["description"] = .string(description)
        }
        if let mimeType = data.mimeType {
            properties["mime_type"] = .string(mimeType)
        }
        if let size = data.size {
            properties["size"] = .number(Double(size))
        }
        if let filePath = data.filePath {
            properties["file_path"] = .string(filePath)
        }
        if let previewImageUrl = data.previewImageUrl {
            properties["preview_image_url"] = .string(previewImageUrl)
        }
        if let videoLength = data.videoLength {
            properties["video_length"] = .number(Double(videoLength))
        }
        if let previewVideoUrl = data.previewVideoUrl {
            properties["preview_video_url"] = .string(previewVideoUrl)
        }

        return .object(properties: properties)
    }
}

// MARK: - Media Item

private enum MediaItem: Identifiable {
    case image(URL)
    case video(URL)

    var id: String {
        switch self {
        case let .image(url):
            return "image-\(url.absoluteString)"
        case let .video(url):
            return "video-\(url.absoluteString)"
        }
    }
}

// MARK: - Fullscreen Media Viewer

private struct FullscreenMediaViewer: View {
    let mediaItem: MediaItem
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                switch mediaItem {
                case let .image(url):
                    imageViewer(url: url, geometry: geometry)

                case let .video(url):
                    videoViewer(url: url)
                }

                // Close button - positioned on left for videos to avoid overlap with volume control
                VStack {
                    HStack {
                        if case .video = mediaItem {
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .padding(.leading, 62)
                            Spacer()
                        } else {
                            Spacer()
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func imageViewer(url: URL, geometry: GeometryProxy) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(loadedImage):
                loadedImage
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                // Dismiss if pinched out below threshold
                                if scale < 0.7 {
                                    onDismiss()
                                } else if scale < 1.0 {
                                    // Snap back to normal scale
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else {
                                    lastScale = scale
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }

            case .failure:
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Failed to load image")
                        .foregroundStyle(.white.opacity(0.6))
                }

            case .empty:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

            @unknown default:
                EmptyView()
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    private func videoViewer(url: URL) -> some View {
        VideoPlayer(player: player ?? AVPlayer(url: url))
            .ignoresSafeArea()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        // Dismiss if pinched out below threshold
                        if scale < 0.7 {
                            onDismiss()
                        } else if scale < 1.0 {
                            // Snap back to normal scale
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        } else {
                            lastScale = scale
                        }
                    }
            )
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
    }
}

// MARK: - Preview

#Preview("Image Content") {
    NavigationStack {
        ContentDetailSheet(
            content: Content(
                id: "content-1",
                itemId: "item-1",
                _type: .image,
                data: Content.dataPayload(additionalProperties: [
                    "title": try! .init(unvalidatedValue: "Sample Image"),
                    "description": try! .init(unvalidatedValue: "A beautiful landscape photo"),
                    "mime_type": try! .init(unvalidatedValue: "image/jpeg"),
                    "size": try! .init(unvalidatedValue: 2_500_000),
                    "preview_image_url": try! .init(unvalidatedValue: "https://picsum.photos/800/600"),
                ]),
                createdAt: Date(),
                updatedAt: Date()
            ),
            contentSchemas: .constant([]),
            onEdit: {},
            isViewOnly: false
        )
    }
}

#Preview("Video Content") {
    NavigationStack {
        ContentDetailSheet(
            content: Content(
                id: "content-2",
                itemId: "item-1",
                _type: .video,
                data: Content.dataPayload(additionalProperties: [
                    "title": try! .init(unvalidatedValue: "Sample Video"),
                    "description": try! .init(unvalidatedValue: "A short demo video"),
                    "mime_type": try! .init(unvalidatedValue: "video/mp4"),
                    "size": try! .init(unvalidatedValue: 15_000_000),
                    "video_length": try! .init(unvalidatedValue: 120),
                ]),
                createdAt: Date(),
                updatedAt: Date()
            ),
            contentSchemas: .constant([]),
            onEdit: {},
            isViewOnly: false
        )
    }
}

#Preview("File Content - View Only") {
    NavigationStack {
        ContentDetailSheet(
            content: Content(
                id: "content-3",
                itemId: "item-1",
                _type: .file,
                data: Content.dataPayload(additionalProperties: [
                    "title": try! .init(unvalidatedValue: "Document.pdf"),
                    "description": try! .init(unvalidatedValue: "Important document"),
                    "mime_type": try! .init(unvalidatedValue: "application/pdf"),
                    "size": try! .init(unvalidatedValue: 500_000),
                ]),
                createdAt: Date(),
                updatedAt: Date()
            ),
            contentSchemas: .constant([]),
            onEdit: {},
            isViewOnly: true
        )
    }
}
