//
//  JsonSchemaEditor.swift
//  JsonSchemaEditor
//
//  A SwiftUI package for visually editing JSON schemas
//

// Re-export all public types
@_exported import Foundation
@_exported import JSONSchema
@_exported import SwiftUI

// Models
public typealias JSPropertyType = PropertyType
public typealias JSRootSchemaType = RootSchemaType
public typealias JSJsonSchema = JsonSchema
public typealias JSPropertyItem = PropertyItem

/// Views
public typealias JSSchemaEditorView = JsonSchemaEditorView

// MARK: - Preview

#Preview("Empty Schema") {
    @Previewable @State var schema: JSONSchema? = nil
    Form {
        JsonSchemaEditorView(schema: $schema)
    }
    .scrollDismissesKeyboard(.interactively)
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
    Form {
        JsonSchemaEditorView(schema: $schema)
    }
    .scrollDismissesKeyboard(.interactively)
}
