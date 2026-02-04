//
//  PositionFormSheet.swift
//  RxStorage
//
//  Form sheet for adding a position with schema selection and dynamic form
//

import JSONSchema
import JSONSchemaForm
import OpenAPIRuntime
import RxStorageCore
import SwiftUI

/// Position form sheet for adding positions to items
struct PositionFormSheet: View {
    @Binding var positionSchemas: [PositionSchema]
    let onSubmit: (PositionSchema, [String: RxStorageCore.AnyCodable]) -> Void

    @State private var selectedSchemaId: Int?
    @State private var formData: FormData = .object(properties: [:])
    @State private var showingSchemaSheet = false
    @Environment(\.dismiss) private var dismiss

    var selectedSchema: PositionSchema? {
        positionSchemas.first { $0.id == selectedSchemaId }
    }

    /// Check if form has data
    private var hasFormData: Bool {
        if case let .object(properties) = formData {
            return !properties.isEmpty
        }
        return false
    }

    var body: some View {
        Form {
            // Schema picker with inline creation
            Section {
                Picker("Schema", selection: $selectedSchemaId) {
                    Text("Select a schema").tag(nil as Int?)
                    ForEach(positionSchemas) { schema in
                        Text(schema.name).tag(schema.id as Int?)
                    }
                }

                Button {
                    showingSchemaSheet = true
                } label: {
                    Label("Create New Schema", systemImage: "plus.circle")
                }
            } header: {
                Text("Position Schema")
            }

            // Dynamic form when schema selected
            if let schema = selectedSchema,
               let jsonSchema = parseSchema(from: schema.schema)
            {
                Section("Position Data") {
                    JSONSchemaForm(
                        schema: jsonSchema,
                        formData: $formData,
                        showSubmitButton: false
                    )
                }

                // Submit button
                Section {
                    Button("Add Position") {
                        handleSubmit(schema: schema)
                    }
                    .disabled(!hasFormData)
                }
            }
        }
        .navigationTitle("Add Position")
        #if os(iOS)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSchemaSheet) {
                NavigationStack {
                    PositionSchemaFormSheet(onCreated: { newSchema in
                        positionSchemas.append(newSchema)
                        selectedSchemaId = newSchema.id
                    })
                }
            }
    }

    // MARK: - Helper Methods

    /// Parse schema from schemaPayload (additionalProperties)
    private func parseSchema(from schemaPayload: PositionSchema.schemaPayload) -> JSONSchema? {
        let dict = schemaPayload.additionalProperties.compactMapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    /// Parse schema dictionary to JSONSchema (reused from PositionSchemaFormSheet)
    private func parseSchema(from dict: [String: RxStorageCore.AnyCodable]) -> JSONSchema? {
        let unwrappedDict = dict.mapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: unwrappedDict) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    private func handleSubmit(schema: PositionSchema) {
        guard let dataDict = formData.toDictionary() as? [String: Any] else { return }
        let anyCodableData = dataDict.mapValues { RxStorageCore.AnyCodable($0) }
        onSubmit(schema, anyCodableData)
        dismiss()
    }
}

#Preview {
    @Previewable @State var schemas: [PositionSchema] = []
    NavigationStack {
        PositionFormSheet(
            positionSchemas: $schemas,
            onSubmit: { _, _ in }
        )
    }
}
