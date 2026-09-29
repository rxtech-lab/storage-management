//
//  LabelBitmap.swift
//  RxStorageCore
//
//  1-bit raster for thermal label printers
//

import CoreGraphics
import Foundation

/// A monochrome label raster, one row per dot line along the tape feed.
///
/// Each row holds `headDots` bits packed MSB-first, so a 96-dot head uses 12 bytes per row.
public struct LabelBitmap: Sendable {
    /// Number of dots across the print head
    public let headDots: Int
    /// Number of dot lines along the tape (the label length)
    public let rows: Int
    /// Packed raster data, `rows * headDots / 8` bytes
    public let data: Data
    /// Thresholded image in the orientation it was rendered, for on-screen preview
    public let preview: CGImage

    public enum Failure: LocalizedError, Equatable {
        case invalidSize(width: Int, height: Int, headDots: Int)
        case renderFailed

        public var errorDescription: String? {
            switch self {
            case let .invalidSize(width, height, headDots):
                "Label image is \(width)×\(height) but the printer needs one side to be \(headDots) dots."
            case .renderFailed:
                "Failed to render the label image."
            }
        }
    }

    /// Creates a raster from a rendered label image.
    ///
    /// - Parameters:
    ///   - image: Horizontal labels are `length × headDots` (text runs along the tape).
    ///     Vertical labels are `headDots × length` (text runs across the tape) and are rotated onto the head.
    ///   - headDots: Print head width in dots. Must be a multiple of 8.
    ///   - threshold: Gray values below this print as black.
    public init(image: CGImage, headDots: Int, threshold: UInt8 = 128) throws {
        let width = image.width
        let height = image.height
        let isVertical = width == headDots && height != headDots
        guard headDots % 8 == 0, isVertical || height == headDots, width > 0, height > 0 else {
            throw Failure.invalidSize(width: width, height: height, headDots: headDots)
        }

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw Failure.renderFailed }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else { throw Failure.renderFailed }

        // Memory row 0 is the top of the image.
        let pixels = pixelData.assumingMemoryBound(to: UInt8.self)
        for index in 0 ..< width * height {
            pixels[index] = pixels[index] < threshold ? 0 : 255
        }
        guard let preview = context.makeImage() else { throw Failure.renderFailed }

        let rows = isVertical ? height : width
        let bytesPerRow = headDots / 8
        var raster = [UInt8](repeating: 0, count: rows * bytesPerRow)
        for row in 0 ..< rows {
            for column in 0 ..< headDots {
                // Head column 0 maps to the bottom edge of a horizontal label. A vertical
                // label is rotated 90° clockwise first so its top edge leads out of the printer.
                let pixel = isVertical
                    ? pixels[(rows - 1 - row) * width + (headDots - 1 - column)]
                    : pixels[(headDots - 1 - column) * width + row]
                if pixel == 0 {
                    raster[row * bytesPerRow + column / 8] |= 0x80 >> (column % 8)
                }
            }
        }

        self.headDots = headDots
        self.rows = rows
        data = Data(raster)
        self.preview = preview
    }

    /// Label length in millimeters for a printer resolution
    public func lengthInMillimeters(dotsPerMillimeter: Double) -> Double {
        Double(rows) / dotsPerMillimeter
    }
}
