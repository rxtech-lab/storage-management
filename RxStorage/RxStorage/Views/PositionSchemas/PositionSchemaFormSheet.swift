//
//  PositionSchemaFormSheet.swift
//  RxStorage
//
//  Position schema create/edit form
//

import JSONSchema
import JsonSchemaEditor
import OpenAPIRuntime
import RxStorageCore
import SwiftUI

/// Position schema form sheet for creating or editing schemas
struct PositionSchemaFormSheet: View {
    let schema: PositionSchema?
    let onCreated: ((PositionSchema) -> Void)?

    @State private var viewModel: PositionSchemaFormViewModel
    @State private var jsonSchema: JSONSchema?
    @Environment(\.dismiss) private var dismiss
    @Environment(EventViewModel.self) private var eventViewModel

    init(schema: PositionSchema? = nil, onCreated: ((PositionSchema) -> Void)? = nil) {
        self.schema = schema
        self.onCreated = onCreated
        _viewModel = State(initialValue: PositionSchemaFormViewModel(schema: schema))
        // Initialize jsonSchema from schema if editing
        if let schema = schema {
            _jsonSchema = State(initialValue: Self.parseSchema(from: schema.schema))
        } else {
            _jsonSchema = State(initialValue: nil)
        }
    }

    /// Parse schema from schemaPayload (additionalProperties)
    private static func parseSchema(from schemaPayload: PositionSchema.schemaPayload) -> JSONSchema? {
        let dict = schemaPayload.additionalProperties.compactMapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    /// Parse schema dictionary to JSONSchema
    private static func parseSchema(from dict: [String: RxStorageCore.AnyCodable]) -> JSONSchema? {
        // Convert AnyCodable values to their underlying values for JSONSerialization
        let unwrappedDict = dict.mapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: unwrappedDict, options: []) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    /// Convert JSONSchema to JSON string
    private static func stringifySchema(_ schema: JSONSchema?) -> String {
        guard let schema = schema else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(schema) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Binding that syncs schema changes back to view model
    private var schemaBinding: Binding<JSONSchema?> {
        Binding(
            get: { jsonSchema },
            set: { newSchema in
                jsonSchema = newSchema
                viewModel.schemaJSON = Self.stringifySchema(newSchema)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.name)
                    .accessibilityIdentifier("schema-form-name-field")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            } header: {
                Text("Information")
            }

            JsonSchemaEditorView(schema: schemaBinding)

            // Validation Errors
            if !viewModel.validationErrors.isEmpty {
                Section {
                    ForEach(Array(viewModel.validationErrors.keys), id: \.self) { key in
                        if let error = viewModel.validationErrors[key] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(schema == nil ? "New Schema" : "Edit Schema")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("schema-form-cancel-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(schema == nil ? "Create" : "Save") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("schema-form-submit-button")
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                        .background {
                            #if os(iOS)
                                Color(uiColor: .systemBackground)
                            #elseif os(macOS)
                                Color(nsColor: .windowBackgroundColor)
                            #endif
                        }
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            let savedSchema = try await viewModel.submit()
            // Emit event based on create vs update
            if schema == nil {
                eventViewModel.emit(.positionSchemaCreated(id: savedSchema.id))
            } else {
                eventViewModel.emit(.positionSchemaUpdated(id: savedSchema.id))
            }
            // If callback provided, call with created schema
            onCreated?(savedSchema)
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }
}

#Preview {
    NavigationStack {
        PositionSchemaFormSheet()
    }
}
