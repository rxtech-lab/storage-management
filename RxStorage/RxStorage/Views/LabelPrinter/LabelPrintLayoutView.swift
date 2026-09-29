//
//  LabelPrintLayoutView.swift
//  RxStorage
//
//  Label content rendered at printer resolution (1 point = 1 dot)
//

import RxStorageCore
import SwiftUI

// MARK: - Options

/// Direction the label text runs relative to the tape
enum LabelOrientation: String, CaseIterable, Identifiable {
    /// Text runs along the tape; length grows with the longest line
    case horizontal
    /// Text runs across the tape; length grows with the number of lines
    case vertical

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        }
    }

    var icon: String {
        switch self {
        case .horizontal: "rectangle"
        case .vertical: "rectangle.portrait"
        }
    }
}

/// Which item fields appear on the label and how they are laid out
struct LabelPrintOptions: Equatable {
    var showTitle = true
    var showDescription = false
    var showDate = false
    var showLocation = false
    var orientation: LabelOrientation = .horizontal

    var hasContent: Bool {
        showTitle || showDescription || showDate || showLocation
    }
}

// MARK: - Layout View

/// Label content sized in printer dots. The side across the tape is fixed to the
/// print head width; the length along the tape is derived from the content.
struct LabelPrintLayoutView: View {
    let item: StorageItemDetail
    let options: LabelPrintOptions
    let headDots: Int
    let dotsPerMillimeter: Double

    private var isVertical: Bool {
        options.orientation == .vertical
    }

    private var title: String? {
        options.showTitle ? item.title : nil
    }

    private var itemDescription: String? {
        guard options.showDescription, let description = item.description, !description.isEmpty else { return nil }
        return description
    }

    private var date: String? {
        options.showDate ? (item.itemDate ?? item.createdAt).formatted(date: .abbreviated, time: .omitted) : nil
    }

    private var location: String? {
        options.showLocation ? item.location?.value1.title : nil
    }

    var body: some View {
        LabelLengthLayout(
            isVertical: isVertical,
            thickness: CGFloat(headDots),
            minLength: (15 * dotsPerMillimeter).rounded(),
            maxLength: (150 * dotsPerMillimeter).rounded()
        ) {
            Group {
                if isVertical {
                    verticalContent
                } else {
                    horizontalContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isVertical ? .topLeading : .leading)
        }
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    /// Up to three single-line rows along the tape
    private var horizontalContent: some View {
        let meta = [date, location].compactMap { $0 }.joined(separator: " · ")
        let lineCount = [title, itemDescription, meta.isEmpty ? nil : meta].compactMap { $0 }.count
        let titleSize: CGFloat = lineCount <= 1 ? 40 : lineCount == 2 ? 30 : 26

        return VStack(alignment: .leading, spacing: 1) {
            if let title {
                Text(title).font(.system(size: titleSize, weight: .bold))
            }
            if let itemDescription {
                Text(itemDescription).font(.system(size: 15))
            }
            if !meta.isEmpty {
                Text(meta).font(.system(size: 14))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Wrapped rows stacked down the tape
    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title).font(.system(size: 17, weight: .bold)).lineLimit(4)
            }
            if let itemDescription {
                Text(itemDescription).font(.system(size: 12)).lineLimit(8)
            }
            if let date {
                Text(date).font(.system(size: 11)).lineLimit(1)
            }
            if let location {
                Text(location).font(.system(size: 11)).lineLimit(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
    }
}

// MARK: - Length Layout

/// Fixes one side to the print head width and sizes the other side to the content's
/// ideal length, clamped to `minLength...maxLength` (overflowing text truncates).
private struct LabelLengthLayout: Layout {
    let isVertical: Bool
    let thickness: CGFloat
    let minLength: CGFloat
    let maxLength: CGFloat

    func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let ideal: CGFloat
        if isVertical {
            ideal = subviews.first?.sizeThatFits(ProposedViewSize(width: thickness, height: nil)).height ?? 0
        } else {
            ideal = subviews.first?.sizeThatFits(ProposedViewSize(width: nil, height: thickness)).width ?? 0
        }
        let length = min(max(ideal, minLength), maxLength).rounded(.up)
        return isVertical ? CGSize(width: thickness, height: length) : CGSize(width: length, height: thickness)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - Rendering

extension LabelPrintLayoutView {
    /// Renders the label at one pixel per dot and converts it to a printer raster
    @MainActor
    func renderBitmap() throws -> LabelBitmap {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw LabelBitmap.Failure.renderFailed }
        return try LabelBitmap(image: image, headDots: headDots)
    }
}
