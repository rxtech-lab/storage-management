//
//  RawJsonEditorView.swift
//  JsonSchemaEditor
//

import SwiftUI

/// Raw JSON editing mode
public struct RawJsonEditorView: View {
    @Bindable var viewModel: JsonSchemaEditorViewModel
    let disabled: Bool

    public init(viewModel: JsonSchemaEditorViewModel, disabled: Bool = false) {
        self.viewModel = viewModel
        self.disabled = disabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JSON Schema")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.rawJson)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.jsonError != nil ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .disabled(disabled)
                .onChange(of: viewModel.rawJson) { _, newValue in
                    viewModel.handleRawJsonChange(newValue)
                }

            if let error = viewModel.jsonError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
