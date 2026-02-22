//
//  QRPrintConfiguration.swift
//  RxStorage
//
//  Data model for QR code print configuration
//

import OpenAPIRuntime
import RxStorageCore
import SwiftUI

// MARK: - Print Field

/// Fields that can be included in the QR code print layout
enum QRPrintField: String, CaseIterable, Identifiable, Hashable, Codable {
    case title
    case category
    case location
    case positions
    case description

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .title: "Title"
        case .category: "Category"
        case .location: "Location"
        case .description: "Description"
        case .positions: "Positions"
        }
    }

    var icon: String {
        switch self {
        case .title: "textformat"
        case .category: "folder"
        case .location: "mappin"
        case .description: "text.alignleft"
        case .positions: "mappin.and.ellipse"
        }
    }
}

// MARK: - QR Code Position

/// Position of the QR code relative to metadata
enum QRCodePosition: String, CaseIterable, Identifiable, Codable {
    case top
    case bottom
    case left
    case right

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }

    var icon: String {
        switch self {
        case .top: "arrow.up.square"
        case .bottom: "arrow.down.square"
        case .left: "arrow.left.square"
        case .right: "arrow.right.square"
        }
    }

    /// Whether this position uses a horizontal (side-by-side) layout
    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

// MARK: - Print Size Unit

/// Unit for displaying and entering custom page dimensions
enum PrintSizeUnit: String, CaseIterable, Identifiable, Codable {
    case points
    case millimeters

    var id: String {
        rawValue
    }

    var abbreviation: String {
        switch self {
        case .points: "pt"
        case .millimeters: "mm"
        }
    }

    /// Convert points to this unit
    func fromPoints(_ pts: CGFloat) -> CGFloat {
        switch self {
        case .points: pts
        case .millimeters: pts * 25.4 / 72.0
        }
    }

    /// Convert from this unit to points
    func toPoints(_ value: CGFloat) -> CGFloat {
        switch self {
        case .points: value
        case .millimeters: value * 72.0 / 25.4
        }
    }
}

// MARK: - Print Page Size

/// Preset and custom paper sizes for QR code printing (dimensions in points: 1 pt = 1/72 inch)
enum PrintPageSize: Hashable, Identifiable {
    case usLetter // 612 x 792 (8.5 x 11 in)
    case a4 // 595 x 842 (210 x 297 mm)
    case a5 // 420 x 595 (148 x 210 mm)
    case label4x6 // 288 x 432 (4 x 6 in)
    case label62x100 // 176 x 283 (62 x 100 mm)
    case custom(width: CGFloat, height: CGFloat)

    var id: String {
        switch self {
        case .usLetter: "usLetter"
        case .a4: "a4"
        case .a5: "a5"
        case .label4x6: "label4x6"
        case .label62x100: "label62x100"
        case let .custom(w, h): "custom_\(w)_\(h)"
        }
    }

    var displayName: String {
        switch self {
        case .usLetter: "US Letter"
        case .a4: "A4"
        case .a5: "A5"
        case .label4x6: "4×6 Label"
        case .label62x100: "62×100mm Label"
        case .custom: "Custom"
        }
    }

    var width: CGFloat {
        switch self {
        case .usLetter: 612
        case .a4: 595
        case .a5: 420
        case .label4x6: 288
        case .label62x100: 176
        case let .custom(w, _): w
        }
    }

    var height: CGFloat {
        switch self {
        case .usLetter: 792
        case .a4: 842
        case .a5: 595
        case .label4x6: 432
        case .label62x100: 283
        case let .custom(_, h): h
        }
    }

    /// All preset sizes for use in pickers
    static let allPresets: [PrintPageSize] = [.usLetter, .a4, .a5, .label4x6, .label62x100]
}

extension PrintPageSize: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, width, height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "usLetter": self = .usLetter
        case "a4": self = .a4
        case "a5": self = .a5
        case "label4x6": self = .label4x6
        case "label62x100": self = .label62x100
        case "custom":
            let w = try container.decode(CGFloat.self, forKey: .width)
            let h = try container.decode(CGFloat.self, forKey: .height)
            self = .custom(width: w, height: h)
        default: self = .usLetter
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .usLetter: try container.encode("usLetter", forKey: .type)
        case .a4: try container.encode("a4", forKey: .type)
        case .a5: try container.encode("a5", forKey: .type)
        case .label4x6: try container.encode("label4x6", forKey: .type)
        case .label62x100: try container.encode("label62x100", forKey: .type)
        case let .custom(w, h):
            try container.encode("custom", forKey: .type)
            try container.encode(w, forKey: .width)
            try container.encode(h, forKey: .height)
        }
    }
}

// MARK: - Print Vertical Alignment

/// Vertical alignment of content on the printed page
enum PrintVerticalAlignment: String, CaseIterable, Identifiable, Codable {
    case top
    case center
    case bottom

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .top: "Top"
        case .center: "Center"
        case .bottom: "Bottom"
        }
    }

    var icon: String {
        switch self {
        case .top: "arrow.up.to.line"
        case .center: "arrow.up.and.down"
        case .bottom: "arrow.down.to.line"
        }
    }

    var verticalAlignment: VerticalAlignment {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }
}

// MARK: - Print Alignment

/// Horizontal alignment for the print layout
enum PrintAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        }
    }

    var icon: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

// MARK: - Print Configuration

/// Observable configuration model for QR code print settings
@Observable
final class QRPrintConfiguration {
    var fieldOrder: [QRPrintField]
    var enabledFields: Set<QRPrintField>
    var qrCodePosition: QRCodePosition
    var alignment: PrintAlignment
    /// Base font size in points (body text). Title and label sizes are derived.
    var fontSize: CGFloat
    var pageSize: PrintPageSize
    var sizeUnit: PrintSizeUnit
    var verticalAlignment: PrintVerticalAlignment
    /// Padding in points around the content
    var padding: CGFloat
    /// QR code size in points
    var qrCodeSize: CGFloat
    /// Vertical spacing in points between elements
    var verticalSpacing: CGFloat
    /// Horizontal spacing in points between QR code and metadata (left/right layout)
    var horizontalSpacing: CGFloat

    /// Returns enabled fields in their current order
    var activeFields: [QRPrintField] {
        fieldOrder.filter { enabledFields.contains($0) }
    }

    /// Default QR code size scaled to page, capped at 200pt
    static func defaultQRCodeSize(for pageSize: PrintPageSize) -> CGFloat {
        min(min(pageSize.width, pageSize.height) * 0.3, 200)
    }

    /// Title font (1.5x base size, bold)
    var titleFont: Font {
        .system(size: fontSize * 1.5, weight: .bold)
    }

    /// Body font (base size)
    var bodyFont: Font {
        .system(size: fontSize)
    }

    /// Label font (0.75x base size)
    var labelFont: Font {
        .system(size: fontSize * 0.75)
    }

    /// Default padding proportional to page width
    static func defaultPadding(for pageSize: PrintPageSize) -> CGFloat {
        (pageSize.width * 0.065).rounded()
    }

    init(
        fieldOrder: [QRPrintField] = QRPrintField.allCases,
        enabledFields: Set<QRPrintField> = [.title, .category, .location],
        qrCodePosition: QRCodePosition = .top,
        alignment: PrintAlignment = .center,
        fontSize: CGFloat = 17,
        pageSize: PrintPageSize = .label62x100,
        sizeUnit: PrintSizeUnit = .points,
        verticalAlignment: PrintVerticalAlignment = .top,
        padding: CGFloat? = nil,
        qrCodeSize: CGFloat? = nil,
        verticalSpacing: CGFloat = 24,
        horizontalSpacing: CGFloat = 24
    ) {
        self.fieldOrder = fieldOrder
        self.enabledFields = enabledFields
        self.qrCodePosition = qrCodePosition
        self.alignment = alignment
        self.fontSize = fontSize
        self.pageSize = pageSize
        self.sizeUnit = sizeUnit
        self.verticalAlignment = verticalAlignment
        self.padding = padding ?? QRPrintConfiguration.defaultPadding(for: pageSize)
        self.qrCodeSize = qrCodeSize ?? QRPrintConfiguration.defaultQRCodeSize(for: pageSize)
        self.verticalSpacing = verticalSpacing
        self.horizontalSpacing = horizontalSpacing
    }

    // MARK: - Persistence

    private static let storageKey = "QRPrintConfiguration"

    /// Codable snapshot for UserDefaults persistence
    private struct StoredConfig: Codable {
        var fieldOrder: [QRPrintField]
        var enabledFields: [QRPrintField]
        var qrCodePosition: QRCodePosition
        var alignment: PrintAlignment
        var fontSize: CGFloat
        var pageSize: PrintPageSize
        var verticalAlignment: PrintVerticalAlignment
        var padding: CGFloat
        // Optional for backwards compatibility with older saved configs
        var sizeUnit: PrintSizeUnit?
        var qrCodeSize: CGFloat?
        var verticalSpacing: CGFloat?
        var horizontalSpacing: CGFloat?
    }

    /// Save current configuration to UserDefaults
    func save() {
        let stored = StoredConfig(
            fieldOrder: fieldOrder,
            enabledFields: Array(enabledFields),
            qrCodePosition: qrCodePosition,
            alignment: alignment,
            fontSize: fontSize,
            pageSize: pageSize,
            verticalAlignment: verticalAlignment,
            padding: padding,
            sizeUnit: sizeUnit,
            qrCodeSize: qrCodeSize,
            verticalSpacing: verticalSpacing,
            horizontalSpacing: horizontalSpacing
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Load last saved configuration, or return default
    static func loadSaved() -> QRPrintConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(StoredConfig.self, from: data)
        else {
            return QRPrintConfiguration()
        }
        // Migrate: insert any new fields at their default position
        var fieldOrder = stored.fieldOrder
        let defaultOrder = QRPrintField.allCases
        for (defaultIndex, field) in defaultOrder.enumerated() where !fieldOrder.contains(field) {
            let insertAt = min(defaultIndex, fieldOrder.count)
            fieldOrder.insert(field, at: insertAt)
        }
        return QRPrintConfiguration(
            fieldOrder: fieldOrder,
            enabledFields: Set(stored.enabledFields),
            qrCodePosition: stored.qrCodePosition,
            alignment: stored.alignment,
            fontSize: stored.fontSize,
            pageSize: stored.pageSize,
            sizeUnit: stored.sizeUnit ?? .points,
            verticalAlignment: stored.verticalAlignment,
            padding: stored.padding,
            qrCodeSize: stored.qrCodeSize,
            verticalSpacing: stored.verticalSpacing ?? 24,
            horizontalSpacing: stored.horizontalSpacing ?? 24
        )
    }

    func toggleField(_ field: QRPrintField) {
        if enabledFields.contains(field) {
            enabledFields.remove(field)
        } else {
            enabledFields.insert(field)
        }
    }

    func moveFields(from source: IndexSet, to destination: Int) {
        fieldOrder.move(fromOffsets: source, toOffset: destination)
    }

    /// Extract the string value for a field from a StorageItemDetail
    func fieldValue(for field: QRPrintField, item: StorageItemDetail) -> String? {
        switch field {
        case .title:
            return item.title
        case .category:
            return item.category?.value1.name
        case .location:
            return item.location?.value1.title
        case .description:
            return item.description
        case .positions:
            return Self.positionsSummary(item.positions)
        }
    }

    /// Summarize all positions into a single printable string
    private static func positionsSummary(_ positions: [PositionRef]) -> String? {
        guard !positions.isEmpty else { return nil }
        return positions.map { position in
            position.data.additionalProperties.map { key, value -> String in
                let valueStr: String
                switch value.value {
                case let str as String: valueStr = str
                case let num as Int: valueStr = String(num)
                case let num as Double: valueStr = String(format: "%.2f", num)
                case let bool as Bool: valueStr = bool ? "Yes" : "No"
                default: valueStr = String(describing: value.value ?? "")
                }
                return "\(key): \(valueStr)"
            }.joined(separator: ", ")
        }.joined(separator: "\n")
    }
}
