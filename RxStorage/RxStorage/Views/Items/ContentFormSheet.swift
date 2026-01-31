//
//  ContentFormSheet.swift
//  RxStorage
//
//  Form sheet for adding content with type selection and dynamic form
//

import JSONSchema
import JSONSchemaForm
import RxStorageCore
import SwiftUI

/// Content form sheet for adding content to items
struct ContentFormSheet: View {
    @Binding var contentSchemas: [ContentSchema]
    let onSubmit: (Content.ContentType, [String: RxStorageCore.AnyCodable]) -> Void

    @State private var selectedType: Content.ContentType?
    @State private var formData: FormData = .object(properties: [:])
    @Environment(\.dismiss) private var dismiss

    var selectedSchema: ContentSchema? {
        guard let type = selectedType else { return nil }
        return contentSchemas.first { $0.type == type.rawValue }
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
                    Text("Select a type").tag(nil as Content.ContentType?)
                    ForEach(Content.ContentType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type as Content.ContentType?)
                    }
                }
                .onChange(of: selectedType) { _, _ in
                    // Reset form data when type changes
                    formData = .object(properties: [:])
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
                    Button("Add Content") {
                        handleSubmit()
                    }
                    .disabled(!hasFormData)
                }
            }
        }
        .navigationTitle("Add Content")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
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

    private func handleSubmit() {
        guard let type = selectedType,
              let dataDict = formData.toDictionary() as? [String: Any]
        else { return }

        let anyCodableData = dataDict.mapValues { RxStorageCore.AnyCodable($0) }
        onSubmit(type, anyCodableData)
        dismiss()
    }
}

#Preview {
    @Previewable @State var schemas: [ContentSchema] = [
        ContentSchema(
            type: "file",
            name: "File",
            schema: [
                "type": RxStorageCore.AnyCodable("object"),
                "properties": RxStorageCore.AnyCodable([
                    "title": ["type": "string", "title": "Title"],
                    "description": ["type": "string", "title": "Description"],
                ] as [String: Any]),
            ]
        ),
    ]
    NavigationStack {
        ContentFormSheet(
            contentSchemas: $schemas,
            onSubmit: { _, _ in }
        )
    }
}
