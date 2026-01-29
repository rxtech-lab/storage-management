//
//  JsonSchemaEditorView.swift
//  JsonSchemaEditor
//

import SwiftUI
import JSONSchema

/// Main JSON Schema Editor view with dual-mode editing
public struct JsonSchemaEditorView: View {
    @Binding var schema: JSONSchema?
    @State private var viewModel: JsonSchemaEditorViewModel
    private let disabled: Bool

    public init(
        schema: Binding<JSONSchema?>,
        disabled: Bool = false
    ) {
        self._schema = schema
        self._viewModel = State(initialValue: JsonSchemaEditorViewModel(schema: schema.wrappedValue))
        self.disabled = disabled
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Tab picker
            Picker("Editor Mode", selection: $viewModel.activeTab) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .disabled(disabled || (viewModel.activeTab == .raw && viewModel.jsonError != nil))
            .onChange(of: viewModel.activeTab) { oldValue, newValue in
                viewModel.handleTabChange(newValue)
            }

            // Tab content
            ScrollView {
                Group {
                    switch viewModel.activeTab {
                    case .visual:
                        VisualEditorView(viewModel: viewModel, disabled: disabled)
                    case .raw:
                        RawJsonEditorView(viewModel: viewModel, disabled: disabled)
                    }
                }
                .padding(.horizontal, 1) // Prevent clipping
            }
        }
        .onChange(of: viewModel.items) { _, _ in
            syncToBinding()
        }
        .onChange(of: viewModel.schemaType) { _, _ in
            syncToBinding()
        }
        .onChange(of: viewModel.title) { _, _ in
            syncToBinding()
        }
        .onChange(of: viewModel.schemaDescription) { _, _ in
            syncToBinding()
        }
        .onChange(of: viewModel.arrayItemsType) { _, _ in
            syncToBinding()
        }
    }

    private func syncToBinding() {
        schema = viewModel.buildSchema()
    }
}

// MARK: - Preview

#Preview("Empty Schema") {
    @Previewable @State var schema: JSONSchema? = nil
    JsonSchemaEditorView(schema: $schema)
        .padding()
}

#Preview("Object Schema") {
    @Previewable @State var schema: JSONSchema? = JSONSchema.object(
        title: "Position",
        properties: [
            "shelf": JSONSchema.string(),
            "row": JSONSchema.integer(),
        ],
        required: ["shelf"]
    )
    JsonSchemaEditorView(schema: $schema)
        .padding()
}
