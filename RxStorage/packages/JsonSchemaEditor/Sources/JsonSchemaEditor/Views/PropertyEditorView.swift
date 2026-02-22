//
//  PropertyEditorView.swift
//  JsonSchemaEditor
//

import JSONSchema
import SwiftUI

/// Single property editor
public struct PropertyEditorView: View {
    @Binding var item: PropertyItem
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let isFirst: Bool
    let isLast: Bool
    let disabled: Bool

    @State private var keyError: String?

    public init(
        item: Binding<PropertyItem>,
        onDelete: @escaping () -> Void,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil,
        isFirst: Bool = true,
        isLast: Bool = true,
        disabled: Bool = false
    ) {
        _item = item
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.isFirst = isFirst
        self.isLast = isLast
        self.disabled = disabled
    }

    public var body: some View {
        Section {
            TextField("Property Name", text: $item.key)
                .disabled(disabled)
                .accessibilityIdentifier("schema-editor-property-name")
                .onChange(of: item.key) { _, newValue in
                    validateKey(newValue)
                }

            if let error = keyError {
                Text(error)
                    .foregroundStyle(.red)
            }

            Picker("Type", selection: $item.propertyType) {
                ForEach(PropertyType.allCases, id: \.self) { type in
                    Text(type.displayLabel).tag(type)
                }
            }
            .disabled(disabled)

            TextField("Description", text: $item.propertyDescription)
                .disabled(disabled)

            Toggle("Required", isOn: $item.isRequired)
                .disabled(disabled)

            if item.propertyType == .array {
                Picker("Array Item Type", selection: $item.arrayItemsType) {
                    ForEach(PropertyType.allCases.filter { $0 != .array }, id: \.self) { type in
                        Text(type.displayLabel).tag(type)
                    }
                }
                .disabled(disabled)
            }

            HStack(spacing: 16) {
                if let onMoveUp {
                    Button("Move Up") {
                        onMoveUp()
                    }
                    .disabled(disabled || isFirst)
                }

                if let onMoveDown {
                    Button("Move Down") {
                        onMoveDown()
                    }
                    .disabled(disabled || isLast)
                }

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .disabled(disabled)
            }
        } header: {
            Text(item.key.isEmpty ? "New Property" : item.key)
        }
    }

    private func validateKey(_ key: String) {
        let result = SchemaValidation.validatePropertyKey(key)
        keyError = result.error
    }
}
