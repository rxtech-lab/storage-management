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
        Group {
            Section {
                Picker("Schema Type", selection: $viewModel.schemaType) {
                    ForEach(RootSchemaType.allCases, id: \.self) { type in
                        Text(type.displayLabel).tag(type)
                    }
                }
                .disabled(disabled)
                .onChange(of: viewModel.schemaType) { oldValue, newValue in
                    if oldValue != newValue {
                        viewModel.handleTypeChange(newValue)
                    }
                }

                TextField("Title (optional)", text: $viewModel.title)
                    .disabled(disabled)

                TextField("Description (optional)", text: $viewModel.schemaDescription)
                    .disabled(disabled)
            } header: {
                Text("Schema Settings")
            }

            typeSpecificContent
        }
    }

    @ViewBuilder
    private var typeSpecificContent: some View {
        switch viewModel.schemaType {
        case .object:
            PropertyListView(viewModel: viewModel, disabled: disabled)
        case .array:
            Section {
                Picker("Array Item Type", selection: $viewModel.arrayItemsType) {
                    ForEach(PropertyType.allCases.filter { $0 != .array }, id: \.self) { type in
                        Text(type.displayLabel).tag(type)
                    }
                }
                .disabled(disabled)
            } header: {
                Text("Array Configuration")
            }
        default:
            Section {
                Text("This schema type has no additional configuration")
            }
        }
    }
}
