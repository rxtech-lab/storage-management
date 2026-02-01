//
//  ContentDetailSheet.swift
//  RxStorage
//
//  Detail sheet for viewing content with read-only JSON schema form
//

import JSONSchema
import JSONSchemaForm
import RxStorageCore
import SwiftUI

/// Content detail sheet for viewing content details in read-only mode
struct ContentDetailSheet: View {
    let content: Content
    @Binding var contentSchemas: [ContentSchema]
    let onEdit: () -> Void
    let isViewOnly: Bool

    @State private var formData: FormData = .object(properties: [:])
    @Environment(\.dismiss) private var dismiss

    /// Get the schema for this content's type
    private var selectedSchema: ContentSchema? {
        contentSchemas.first { $0.type == content.type.rawValue }
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

    var body: some View {
        Form {
            // Content type header section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: content.type.icon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.type.displayName)
                            .font(.headline)
                        if let mimeType = content.data.mimeType {
                            Text(mimeType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // File size badge
                    if let size = content.data.formattedSize {
                        Text(size)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
            }

            // Read-only JSON Schema Form for content data
            if let schema = selectedSchema,
               let jsonSchema = parseSchema(from: schema.schema)
            {
                Section("Content Data") {
                    JSONSchemaForm(
                        schema: jsonSchema,
                        formData: $formData,
                        showSubmitButton: false,
                        readonly: true
                    )
                }
            } else {
                // Fallback display when no schema is available
                Section("Content Data") {
                    if let title = content.data.title {
                        LabeledContent("Title", value: title)
                    }
                    if let description = content.data.description {
                        LabeledContent("Description", value: description)
                    }
                    if let filePath = content.data.filePath {
                        LabeledContent("File Path", value: filePath)
                    }
                    if let videoLength = content.data.formattedVideoLength {
                        LabeledContent("Duration", value: videoLength)
                    }
                }
            }

            // Metadata section
            Section("Metadata") {
                LabeledContent("Created") {
                    Text(content.createdAt, style: .date)
                }
                LabeledContent("Updated") {
                    Text(content.updatedAt, style: .date)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(content.data.title ?? "Content Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            if !isViewOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        dismiss()
                        onEdit()
                    }
                }
            }
        }
        .onAppear {
            formData = contentDataToFormData(content.data)
        }
    }

    // MARK: - Helper Methods

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

#Preview("File Content") {
    @Previewable @State var schemas: [ContentSchema] = [
        ContentSchema(
            type: "file",
            name: "File",
            schema: [
                "type": RxStorageCore.AnyCodable("object"),
                "properties": RxStorageCore.AnyCodable([
                    "title": ["type": "string", "title": "Title"],
                    "description": ["type": "string", "title": "Description"],
                    "mime_type": ["type": "string", "title": "MIME Type"],
                    "size": ["type": "number", "title": "Size (bytes)"],
                ] as [String: Any]),
            ]
        ),
    ]
    let content = Content(
        id: 1,
        itemId: 1,
        type: .file,
        data: ContentData(
            title: "Document.pdf",
            description: "An important document",
            mimeType: "application/pdf",
            size: 1_024_000
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
    NavigationStack {
        ContentDetailSheet(
            content: content,
            contentSchemas: $schemas,
            onEdit: {},
            isViewOnly: false
        )
    }
}

#Preview("Video Content - View Only") {
    @Previewable @State var schemas: [ContentSchema] = [
        ContentSchema(
            type: "video",
            name: "Video",
            schema: [
                "type": RxStorageCore.AnyCodable("object"),
                "properties": RxStorageCore.AnyCodable([
                    "title": ["type": "string", "title": "Title"],
                    "video_length": ["type": "number", "title": "Duration (seconds)"],
                ] as [String: Any]),
            ]
        ),
    ]
    let content = Content(
        id: 2,
        itemId: 1,
        type: .video,
        data: ContentData(
            title: "Tutorial.mp4",
            mimeType: "video/mp4",
            size: 50_000_000,
            videoLength: 300
        ),
        createdAt: Date(),
        updatedAt: Date()
    )
    NavigationStack {
        ContentDetailSheet(
            content: content,
            contentSchemas: $schemas,
            onEdit: {},
            isViewOnly: true
        )
    }
}
