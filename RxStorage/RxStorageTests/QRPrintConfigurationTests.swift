//
//  QRPrintConfigurationTests.swift
//  RxStorageTests
//
//  Unit tests for QRPrintConfiguration model
//

import Foundation
@testable import RxStorage
import Testing

@Suite("QRPrintConfiguration Tests")
struct QRPrintConfigurationTests {
    // MARK: - Default State

    @Test("Default configuration has expected initial values")
    func defaultConfiguration() {
        let config = QRPrintConfiguration()

        #expect(config.fieldOrder == QRPrintField.allCases)
        #expect(config.fieldOrder.count == 5)
        #expect(config.enabledFields == [.title, .category, .location])
        #expect(!config.enabledFields.contains(.description))
        #expect(!config.enabledFields.contains(.positions))
        #expect(config.qrCodePosition == .top)
        #expect(config.alignment == .center)
        #expect(config.fontSize == 17)
        #expect(config.pageSize == .usLetter)
        #expect(config.verticalAlignment == .top)
        #expect(config.padding == QRPrintConfiguration.defaultPadding(for: .usLetter))
    }

    // MARK: - Field Toggling

    @Test("Toggle field on and off")
    func toggleField() {
        let config = QRPrintConfiguration()

        // Toggle description on
        config.toggleField(.description)
        #expect(config.enabledFields.contains(.description))

        // Toggle title off
        config.toggleField(.title)
        #expect(!config.enabledFields.contains(.title))

        // Toggle title back on
        config.toggleField(.title)
        #expect(config.enabledFields.contains(.title))
    }

    // MARK: - Field Reordering

    @Test("Move fields reorders correctly")
    func moveFields() {
        let config = QRPrintConfiguration()

        // Move first field (title) to last position
        config.moveFields(from: IndexSet(integer: 0), to: 4)

        #expect(config.fieldOrder[0] == .category)
        #expect(config.fieldOrder[1] == .location)
        #expect(config.fieldOrder[2] == .description)
        #expect(config.fieldOrder[3] == .title)
    }

    // MARK: - Active Fields

    @Test("Active fields returns only enabled fields in order")
    func activeFieldsFiltering() {
        let config = QRPrintConfiguration()

        // Default: title, category, location enabled
        let active = config.activeFields
        #expect(active.count == 3)
        #expect(active[0] == .title)
        #expect(active[1] == .category)
        #expect(active[2] == .location)
        #expect(!active.contains(.description))
    }

    @Test("Active fields reflects both toggle and reorder changes")
    func activeFieldsAfterToggleAndReorder() {
        let config = QRPrintConfiguration(
            enabledFields: [.title, .location]
        )

        // Move location before title
        config.moveFields(from: IndexSet(integer: 2), to: 0)

        let active = config.activeFields
        #expect(active.count == 2)
        #expect(active[0] == .location)
        #expect(active[1] == .title)
    }

    @Test("All fields disabled returns empty active fields")
    func allFieldsDisabled() {
        let config = QRPrintConfiguration()

        // Disable all enabled fields
        config.toggleField(.title)
        config.toggleField(.category)
        config.toggleField(.location)

        #expect(config.activeFields.isEmpty)
    }

    // MARK: - Page Size

    @Test("Page size presets have correct dimensions")
    func pageSizePresets() {
        #expect(PrintPageSize.usLetter.width == 612)
        #expect(PrintPageSize.usLetter.height == 792)
        #expect(PrintPageSize.a4.width == 595)
        #expect(PrintPageSize.a4.height == 842)
        #expect(PrintPageSize.a5.width == 420)
        #expect(PrintPageSize.a5.height == 595)
        #expect(PrintPageSize.label4x6.width == 288)
        #expect(PrintPageSize.label4x6.height == 432)
    }

    @Test("Custom page size uses provided dimensions")
    func customPageSize() {
        let custom = PrintPageSize.custom(width: 300, height: 400)
        #expect(custom.width == 300)
        #expect(custom.height == 400)
        #expect(custom.displayName == "Custom")
    }

    @Test("All presets array contains expected sizes")
    func allPresets() {
        let presets = PrintPageSize.allPresets
        #expect(presets.count == 4)
        #expect(presets.contains(.usLetter))
        #expect(presets.contains(.a4))
        #expect(presets.contains(.a5))
        #expect(presets.contains(.label4x6))
    }

    // MARK: - QR Code Size

    @Test("QR code size scales with page and caps at 200")
    func qrCodeSize() {
        let config = QRPrintConfiguration(pageSize: .usLetter)
        // min(612, 792) * 0.3 = 183.6, capped at 200 → 183.6
        #expect(config.qrCodeSize == min(612 * 0.3, 200))

        let smallConfig = QRPrintConfiguration(pageSize: .label4x6)
        // min(288, 432) * 0.3 = 86.4
        #expect(smallConfig.qrCodeSize == 288 * 0.3)

        let largeConfig = QRPrintConfiguration(pageSize: .custom(width: 1000, height: 1000))
        // min(1000, 1000) * 0.3 = 300, capped at 200
        #expect(largeConfig.qrCodeSize == 200)
    }

    // MARK: - Vertical Alignment

    @Test("Vertical alignment cases have expected display names")
    func verticalAlignmentDisplayNames() {
        #expect(PrintVerticalAlignment.top.displayName == "Top")
        #expect(PrintVerticalAlignment.center.displayName == "Center")
        #expect(PrintVerticalAlignment.bottom.displayName == "Bottom")
    }

    // MARK: - QR Code Position

    @Test("QR code position cases have correct properties")
    func qrCodePositionProperties() {
        #expect(QRCodePosition.top.displayName == "Top")
        #expect(QRCodePosition.bottom.displayName == "Bottom")
        #expect(QRCodePosition.left.displayName == "Left")
        #expect(QRCodePosition.right.displayName == "Right")

        #expect(!QRCodePosition.top.isHorizontal)
        #expect(!QRCodePosition.bottom.isHorizontal)
        #expect(QRCodePosition.left.isHorizontal)
        #expect(QRCodePosition.right.isHorizontal)
    }
}
