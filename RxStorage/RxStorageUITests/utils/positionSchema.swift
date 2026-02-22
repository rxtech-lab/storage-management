//
//  positionSchema.swift
//  RxStorage
//
//  UI test helpers for Position Schema elements
//

import XCTest

extension XCUIApplication {
    // MARK: - Navigation

    var managementTab: XCUIElement {
        buttons["Management"].firstMatch
    }

    var positionSchemasSection: XCUIElement {
        staticTexts["Position Schemas"].firstMatch
    }

    // MARK: - Schema List

    var newSchemaButton: XCUIElement {
        buttons["schema-list-new-button"].firstMatch
    }

    var schemaRow: XCUIElement {
        staticTexts["schema-row"]
    }

    // MARK: - Schema Detail

    var schemaDetailName: XCUIElement {
        staticTexts["schema-detail-name"].firstMatch
    }

    var schemaDetailEditButton: XCUIElement {
        buttons["schema-detail-edit-button"].firstMatch
    }

    // MARK: - Schema Form

    var schemaFormNameField: XCUIElement {
        textFields["schema-form-name-field"].firstMatch
    }

    var schemaFormCancelButton: XCUIElement {
        buttons["schema-form-cancel-button"].firstMatch
    }

    var schemaFormSubmitButton: XCUIElement {
        buttons["schema-form-submit-button"].firstMatch
    }

    // MARK: - Schema Editor (JSON Schema properties)

    var schemaEditorAddPropertyButton: XCUIElement {
        buttons["schema-editor-add-property"].firstMatch
    }

    var schemaEditorPropertyNameField: XCUIElement {
        textFields["schema-editor-property-name"].firstMatch
    }

    // MARK: - Delete Confirmation

    var deleteSchemaConfirmButton: XCUIElement {
        alerts["Delete Schema"].buttons["Delete"].firstMatch
    }

    var deleteSchemaAlert: XCUIElement {
        alerts["Delete Schema"].firstMatch
    }
}
