//
//  JsonSchemaEditorViewTests.swift
//  JsonSchemaEditorTests
//

import Testing
import SwiftUI
import ViewInspector
import JSONSchema
@testable import JsonSchemaEditor

@Suite("JsonSchemaEditorView Tests")
@MainActor
struct JsonSchemaEditorViewTests {

    @Test("View renders with empty state")
    func testRendersWithEmptyState() throws {
        let sut = JsonSchemaEditorView(schema: .constant(nil))

        // Verify the view can be inspected
        let inspection = try sut.inspect()
        _ = inspection // Silence warning
    }

    @Test("View renders with object schema")
    func testRendersWithObjectSchema() throws {
        let schema: JSONSchema? = JSONSchema.object(
            title: "Test",
            properties: [
                "name": JSONSchema.string()
            ]
        )

        let sut = JsonSchemaEditorView(schema: .constant(schema))

        let inspection = try sut.inspect()
        _ = inspection
    }
}

@Suite("PropertyEditorView Tests")
@MainActor
struct PropertyEditorViewTests {

    @Test("Property editor renders")
    func testPropertyEditorRenders() throws {
        let item = PropertyItem(key: "testProperty", property: JSONSchema.string())

        let sut = PropertyEditorView(
            item: .constant(item),
            onDelete: {},
            onMoveUp: nil,
            onMoveDown: nil,
            isFirst: true,
            isLast: true,
            disabled: false
        )

        let inspection = try sut.inspect()
        _ = inspection
    }

    @Test("Property editor shows property name")
    func testShowsPropertyName() throws {
        let item = PropertyItem(key: "myProperty", property: JSONSchema.string())

        let sut = PropertyEditorView(
            item: .constant(item),
            onDelete: {},
            isFirst: true,
            isLast: true,
            disabled: false
        )

        let inspection = try sut.inspect()
        // The property name should be somewhere in the view hierarchy
        let text = try? inspection.find(text: "myProperty")
        #expect(text != nil)
    }

    @Test("Delete button exists")
    func testDeleteButtonExists() throws {
        let item = PropertyItem(key: "test", property: JSONSchema.string())

        let sut = PropertyEditorView(
            item: .constant(item),
            onDelete: { },
            isFirst: true,
            isLast: true,
            disabled: false
        )

        let inspection = try sut.inspect()
        // Find a button with trash icon
        let button = try? inspection.find(ViewType.Button.self)
        #expect(button != nil)
    }

    @Test("Required property shows asterisk")
    func testRequiredPropertyShowsAsterisk() throws {
        let item = PropertyItem(
            key: "required_field",
            property: JSONSchema.string(),
            isRequired: true
        )

        let sut = PropertyEditorView(
            item: .constant(item),
            onDelete: {},
            isFirst: true,
            isLast: true,
            disabled: false
        )

        let inspection = try sut.inspect()
        let asterisk = try? inspection.find(text: "*")
        #expect(asterisk != nil)
    }

    @Test("Disabled state affects controls")
    func testDisabledState() throws {
        let item = PropertyItem(key: "test", property: JSONSchema.string())

        let sut = PropertyEditorView(
            item: .constant(item),
            onDelete: {},
            isFirst: true,
            isLast: true,
            disabled: true
        )

        let inspection = try sut.inspect()
        _ = inspection
    }
}

@Suite("VisualEditorView Tests", .serialized)
@MainActor
struct VisualEditorViewTests {

    @Test("Visual editor renders")
    func testVisualEditorRenders() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = VisualEditorView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        _ = inspection
    }

    @Test("Visual editor shows schema type picker")
    func testShowsSchemaTypePicker() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = VisualEditorView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        // Should contain a picker for schema type
        let picker = try? inspection.find(ViewType.Picker.self)
        #expect(picker != nil)
    }
}

@Suite("PropertyListView Tests", .serialized)
@MainActor
struct PropertyListViewTests {

    @Test("Property list renders empty state")
    func testRendersEmptyState() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = PropertyListView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        _ = inspection

        // Should show empty state message
        let noProperties = try? inspection.find(text: "No Properties")
        #expect(noProperties != nil)
    }

    @Test("Property list shows add button")
    func testShowsAddButton() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = PropertyListView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        let addButton = try? inspection.find(ViewType.Button.self)
        #expect(addButton != nil)
    }

    @Test("Property list with items")
    func testPropertyListWithItems() throws {
        let schema = JSONSchema.object(
            properties: [
                "name": JSONSchema.string(),
                "age": JSONSchema.integer()
            ]
        )
        let viewModel = JsonSchemaEditorViewModel(schema: schema)

        let sut = PropertyListView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        _ = inspection
    }
}

@Suite("RawJsonEditorView Tests", .serialized)
@MainActor
struct RawJsonEditorViewTests {

    @Test("Raw JSON editor renders")
    func testRawJsonEditorRenders() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = RawJsonEditorView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        _ = inspection
    }

    @Test("Raw JSON editor shows TextEditor")
    func testShowsTextEditor() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)

        let sut = RawJsonEditorView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        let textEditor = try? inspection.find(ViewType.TextEditor.self)
        #expect(textEditor != nil)
    }

    @Test("Raw JSON editor shows error when present")
    func testShowsErrorWhenPresent() throws {
        let viewModel = JsonSchemaEditorViewModel(schema: nil)
        viewModel.jsonError = "Test error"

        let sut = RawJsonEditorView(viewModel: viewModel, disabled: false)

        let inspection = try sut.inspect()
        let errorText = try? inspection.find(text: "Test error")
        #expect(errorText != nil)
    }
}
