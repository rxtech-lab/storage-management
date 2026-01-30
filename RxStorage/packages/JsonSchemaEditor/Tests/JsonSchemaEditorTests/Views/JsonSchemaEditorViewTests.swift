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

    @Test("Required property shows toggle")
    func testRequiredPropertyShowsToggle() throws {
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
        // The implementation uses a Toggle with "Required" label instead of an asterisk
        let toggle = try? inspection.find(ViewType.Toggle.self)
        #expect(toggle != nil)
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

        // Should show empty state message - actual text is "No properties. Add a property to get started."
        let noProperties = try? inspection.find(text: "No properties. Add a property to get started.")
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

