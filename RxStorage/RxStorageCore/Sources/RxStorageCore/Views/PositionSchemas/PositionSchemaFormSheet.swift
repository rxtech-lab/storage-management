//
//  PositionSchemaFormSheet.swift
//  RxStorageCore
//
//  Position schema create/edit form
//

import SwiftUI

/// Position schema form sheet for creating or editing schemas
public struct PositionSchemaFormSheet: View {
    let schema: PositionSchema?

    @State private var viewModel: PositionSchemaFormViewModel
    @Environment(\.dismiss) private var dismiss

    public init(schema: PositionSchema? = nil) {
        self.schema = schema
        _viewModel = State(initialValue: PositionSchemaFormViewModel(schema: schema))
    }

    public var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Information")
            }

            Section {
                TextEditor(text: $viewModel.schemaJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button {
                    if viewModel.validateJSON() {
                        // JSON is valid
                    }
                } label: {
                    Label("Validate JSON", systemImage: "checkmark.circle")
                }
            } header: {
                Text("JSON Schema")
            } footer: {
                Text("Enter a valid JSON schema defining the position fields.")
            }

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
