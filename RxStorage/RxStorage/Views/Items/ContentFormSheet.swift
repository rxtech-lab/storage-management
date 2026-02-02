//
//  ContentFormSheet.swift
//  RxStorage
//
//  Form sheet for adding/editing content with type selection and dynamic form
//

import JSONSchema
import JSONSchemaForm
import OpenAPIRuntime
import RxStorageCore
import SwiftUI

/// Content form sheet for adding/editing content to items
struct ContentFormSheet: View {
    @Binding var contentSchemas: [ContentSchema]
    let existingContent: Content?
    let onSubmit: (ContentType, [String: RxStorageCore.AnyCodable]) -> Void

    @State private var selectedType: ContentType?
    @State private var formData: FormData = .object(properties: [:])
    @Environment(\.dismiss) private var dismiss

    /// Check if we're editing an existing content
    private var isEditing: Bool {
        existingContent != nil
    }

    init(
        contentSchemas: Binding<[ContentSchema]>,
        existingContent: Content? = nil,
        onSubmit: @escaping (ContentType, [String: RxStorageCore.AnyCodable]) -> Void
    ) {
        self._contentSchemas = contentSchemas
        self.existingContent = existingContent
        self.onSubmit = onSubmit
    }

    var selectedSchema: ContentSchema? {
        guard let type = selectedType else { return nil }
        return contentSchemas.first(where: { $0._type.rawValue == type.rawValue })
    }

    /// Check if form has data
    private var hasFormData: Bool {
        if case .object(let properties) = formData {
            return !properties.isEmpty
        }
        return false
    }

    var body: some View {
        Form {
            // Content type picker
            Section {
                Picker("Type", selection: $selectedType) {
                    Text("Select a type").tag(nil as ContentType?)
                    ForEach(ContentType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type as ContentType?)
                    }
                }
                .disabled(isEditing)
                .onChange(of: selectedType) { _, _ in
                    // Reset form data when type changes (only for new content)
                    if !isEditing {
                        formData = .object(properties: [:])
                    }
                }
            } header: {
                Text("Content Type")
            }

            // Dynamic form when type selected
            if let schema = selectedSchema,
               let jsonSchema = parseSchema(from: schema.schema)
            {
                Section("Content Data") {
                    JSONSchemaForm(
                        schema: jsonSchema,
                        formData: $formData,
                        showSubmitButton: false
                    )
                }

                // Submit button
                Section {
                    Button(isEditing ? "Save Changes" : "Add Content") {
                        handleSubmit()
                    }
                    .disabled(!hasFormData)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Edit Content" : "Add Content")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if let content = existingContent {
                selectedType = content.type
                formData = contentDataToFormData(content.contentData)
            }
        }
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

    /// Convert ContentData to FormData for editing
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

    private func handleSubmit() {
        guard let type = selectedType,
              let dataDict = formData.toDictionary() as? [String: Any]
        else { return }

        let anyCodableData = dataDict.mapValues { RxStorageCore.AnyCodable($0) }
        onSubmit(type, anyCodableData)
        dismiss()
    }
}

// Previews disabled - generated types have different initializers
// TODO: Update previews to use generated ContentSchema and Content types
