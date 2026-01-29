//
//  PropertyEditorView.swift
//  JsonSchemaEditor
//

import SwiftUI
import JSONSchema

/// Single property editor with expand/collapse
public struct PropertyEditorView: View {
    @Binding var item: PropertyItem
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let isFirst: Bool
    let isLast: Bool
    let disabled: Bool

    @State private var isExpanded: Bool = true
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
        self._item = item
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.isFirst = isFirst
        self.isLast = isLast
        self.disabled = disabled
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                content
            }
        }
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(white: 1.0))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.key.isEmpty ? "New Property" : item.key)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if item.isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                            .fontWeight(.bold)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                if let onMoveUp {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(disabled || isFirst)
                }

                if let onMoveDown {
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(disabled || isLast)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .disabled(disabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        #if os(iOS)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
    }

    private var content: some View {
        VStack(spacing: 12) {
            // Property name and type row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Property Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("property_name", text: $item.key)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: item.key) { _, newValue in
                            validateKey(newValue)
                        }
                    if let error = keyError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PropertyTypePicker(selection: $item.propertyType, disabled: disabled)
                        .labelsHidden()
                        #if os(iOS)
                        .pickerStyle(.menu)
                        #endif
                }
            }

            // Description and Required row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Help text", text: $item.propertyDescription)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("", isOn: $item.isRequired)
                        .labelsHidden()
                }
                .frame(width: 80)
            }

            // Type-specific fields
            typeSpecificFields
        }
        .padding(12)
        .disabled(disabled)
    }

    @ViewBuilder
    private var typeSpecificFields: some View {
        // Array items type
        if item.propertyType == .array {
            VStack(alignment: .leading, spacing: 4) {
                Text("Array Item Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Item Type", selection: $item.arrayItemsType) {
                    ForEach(PropertyType.allCases.filter { $0 != .array }, id: \.self) { type in
                        Text(type.displayLabel).tag(type)
                    }
                }
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
            }
        }
    }

    private func validateKey(_ key: String) {
        let result = SchemaValidation.validatePropertyKey(key)
        keyError = result.error
    }
}
