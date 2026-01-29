//
//  VisualEditorView.swift
//  JsonSchemaEditor
//

import SwiftUI

/// Visual editing mode for the schema
public struct VisualEditorView: View {
    @Bindable var viewModel: JsonSchemaEditorViewModel
    let disabled: Bool

    public init(viewModel: JsonSchemaEditorViewModel, disabled: Bool = false) {
        self.viewModel = viewModel
        self.disabled = disabled
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Schema type selector
            schemaTypeSection

            // Common fields: title and description
            commonFieldsSection

            Divider()

            // Type-specific content
            typeSpecificContent
        }
    }

    private var schemaTypeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schema Type")
                .font(.caption)
                .foregroundStyle(.secondary)
            RootSchemaTypePicker(selection: $viewModel.schemaType, disabled: disabled)
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
                .onChange(of: viewModel.schemaType) { oldValue, newValue in
                    if oldValue != newValue {
                        viewModel.handleTypeChange(newValue)
                    }
                }
        }
    }

    private var commonFieldsSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Schema title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(disabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Schema description", text: $viewModel.schemaDescription)
                    .textFieldStyle(.roundedBorder)
                    .disabled(disabled)
            }
        }
    }

    @ViewBuilder
    private var typeSpecificContent: some View {
        switch viewModel.schemaType {
        case .object:
            PropertyListView(viewModel: viewModel, disabled: disabled)
        case .array:
            arrayItemsEditor
        default:
            primitiveEditor
        }
    }

    private var arrayItemsEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Array Item Type")
                .font(.caption)
                .foregroundStyle(.secondary)
            PropertyTypePicker(selection: $viewModel.arrayItemsType, disabled: disabled)
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
        }
    }

    private var primitiveEditor: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Primitive Schema")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("This schema type has no additional configuration")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
