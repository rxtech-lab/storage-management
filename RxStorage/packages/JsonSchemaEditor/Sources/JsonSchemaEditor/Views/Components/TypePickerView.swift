//
//  TypePickerView.swift
//  JsonSchemaEditor
//

import SwiftUI

/// Picker for selecting schema types
public struct TypePickerView<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    let label: String
    let disabled: Bool

    public init(
        selection: Binding<T>,
        label: String = "Type",
        disabled: Bool = false
    ) {
        self._selection = selection
        self.label = label
        self.disabled = disabled
    }

    public var body: some View {
        Picker(label, selection: $selection) {
            ForEach(Array(T.allCases), id: \.self) { type in
                Text(type.rawValue.capitalized).tag(type)
            }
        }
        .disabled(disabled)
    }
}

/// Specialized picker for RootSchemaType
public struct RootSchemaTypePicker: View {
    @Binding var selection: RootSchemaType
    let disabled: Bool

    public init(selection: Binding<RootSchemaType>, disabled: Bool = false) {
        self._selection = selection
        self.disabled = disabled
    }

    public var body: some View {
        Picker("Schema Type", selection: $selection) {
            ForEach(RootSchemaType.allCases, id: \.self) { type in
                VStack(alignment: .leading) {
                    Text(type.displayLabel)
                }
                .tag(type)
            }
        }
        .disabled(disabled)
    }
}

/// Specialized picker for PropertyType
public struct PropertyTypePicker: View {
    @Binding var selection: PropertyType
    let disabled: Bool

    public init(selection: Binding<PropertyType>, disabled: Bool = false) {
        self._selection = selection
        self.disabled = disabled
    }

    public var body: some View {
        Picker("Type", selection: $selection) {
            ForEach(PropertyType.allCases, id: \.self) { type in
                Text(type.displayLabel).tag(type)
            }
        }
        .disabled(disabled)
    }
}
