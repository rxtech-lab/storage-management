//
//  EnumValuesEditor.swift
//  JsonSchemaEditor
//

import SwiftUI
import JSONSchema

/// Editor for enum values (placeholder - enum support requires separate handling in swift-json-schema)
/// Note: The swift-json-schema package uses a separate EnumSchema type which requires
/// different handling. This component is kept as a placeholder for future implementation.
public struct EnumValuesEditor: View {
    @Binding var item: PropertyItem
    let disabled: Bool

    public init(item: Binding<PropertyItem>, disabled: Bool = false) {
        self._item = item
        self.disabled = disabled
    }

    public var body: some View {
        EmptyView()
    }
}
