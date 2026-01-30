//
//  PositionSchemaFormSheet.swift
//  RxStorage
//
//  Position schema create/edit form
//

import JSONSchema
import JsonSchemaEditor
import RxStorageCore
import SwiftUI

/// Position schema form sheet for creating or editing schemas
struct PositionSchemaFormSheet: View {
    let schema: PositionSchema?

    @State private var viewModel: PositionSchemaFormViewModel
    @State private var jsonSchema: JSONSchema?
    @Environment(\.dismiss) private var dismiss

    init(schema: PositionSchema? = nil) {
        self.schema = schema
        _viewModel = State(initialValue: PositionSchemaFormViewModel(schema: schema))
        // Initialize jsonSchema from schema if editing
        if let schema = schema {
            _jsonSchema = State(initialValue: Self.parseSchema(from: schema.schema))
        } else {
            _jsonSchema = State(initialValue: nil)
        }
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
                    .textInputAutocapitalization(.words)
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
        .navigationTitle(schema == nil ? "New Schema" : "Edit Schema")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(schema == nil ? "Create" : "Save") {
                    Task {
                        await submitForm()
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            try await viewModel.submit()
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
