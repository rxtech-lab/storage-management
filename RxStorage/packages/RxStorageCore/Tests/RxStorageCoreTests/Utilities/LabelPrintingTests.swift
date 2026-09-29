//
//  LabelPrintingTests.swift
//  RxStorageCoreTests
//
//  Tests for the Xiaomi label printer protocol and label rasterization.
//  Hex fixtures were captured from a real xiaomi.printer (firmware 2.1.1_1129).
//

import CoreGraphics
import Foundation
@testable import RxStorageCore
import Testing

@Suite("Xiaomi Printer Protocol Tests")
struct XiaomiPrinterProtocolTests {
    @Test("Status and connected commands match known frames")
    func knownCommands() throws {
        // Independently generated with OpenSSL AES-CBC and Python zlib's seeded CRC32.
        #expect(try XiaomiPrinterProtocol.statusQuery().hexString.replacingOccurrences(of: " ", with: "")
            == "A3201000E7CCAA8DF3A0390713898C7D07C0110EF8996FFE")
        #expect(try XiaomiPrinterProtocol.connected().hexString.replacingOccurrences(of: " ", with: "")
            == "A3201000DAA6330C11E09AF3F87878CDE69F888976E2FFB6")
    }

    @Test("Periodic status broadcast reports buffer and battery")
    func actualPrinterNotification() throws {
        let packet = try XiaomiPrinterProtocol.decode(hex("A300170010011F1200010400004000000204000000000003010016C68E266E"))
        var state = XiaomiPrinterState()
        state.consume(packet)
        #expect(state.bufferFree == 16384)
        #expect(state.battery == 22)
        #expect(state.faults.isEmpty)
        #expect(state.hasStatus)
        #expect(XiaomiPrinterState.isStatusPacket(packet))
    }

    @Test("Printing flag follows live notifications")
    func printingThenIdle() throws {
        let running = hex("A300170010011F12000104000040000002040080000000030100161C0B1D3D")
        let idle = hex("A3202000F13B0EBC6DFA2B9CB2BDEE873964D11509EACE1D1E67AC91F40D0354CC09D96543FA0D82")
        var state = XiaomiPrinterState()
        try state.consume(XiaomiPrinterProtocol.decode(running))
        #expect(state.printing)
        try state.consume(XiaomiPrinterProtocol.decode(idle))
        #expect(!state.printing)
        #expect(state.bufferFree == 16384)
        #expect(state.battery == 22)
    }

    @Test("Fault flags are reported")
    func faults() {
        var state = XiaomiPrinterState()
        state.consume([0x10, 1, 0x12, 0x0B, 0, 1, 4, 0, 0x0B, 0, 0, 0, 2, 1, 0, 0])
        #expect(state.faults == ["Cover open", "No paper", "Print head hot"])
    }

    @Test("Packet stream reassembles fragments and skips noise")
    func fragmentsAndNoise() throws {
        let first = hex("A300170010011F1200010400004000000204000000000003010016C68E266E")
        let completion = try XiaomiPrinterProtocol.frame([0x21, 5, 0x0C, 0, 0])
        var stream = XiaomiPacketStream()
        #expect(stream.append(Data([0xFF, 0xA3, 0xFF]) + Data(first.prefix(7))).isEmpty)
        let packets = stream.append(Data(first.dropFirst(7)) + completion)
        #expect(packets.count == 2)
        #expect(packets.last == [0x21, 5, 0x0C, 0, 0])
        #expect(XiaomiPrinterState.isPrintAcknowledgement(packets[1]))
    }

    @Test("Bad checksum is rejected and stream recovers")
    func badChecksum() throws {
        var bytes = hex("A300170010011F1200010400004000000204000000000003010016C68E266E")
        bytes[8] ^= 0x01
        #expect(throws: XiaomiPrinterProtocol.Failure.invalidFrame) {
            try XiaomiPrinterProtocol.decode(bytes)
        }
        var stream = XiaomiPacketStream()
        let valid = try XiaomiPrinterProtocol.frame([0x21, 5, 0x0C, 0, 0])
        #expect(stream.append(Data(bytes) + valid) == [[0x21, 5, 0x0C, 0, 0]])
    }

    @Test("Print frames split raster into indexed chunks")
    func rasterFrames() throws {
        let frames = try XiaomiPrinterProtocol.printFrames(raster: Data(repeating: 0x55, count: 3840), rows: 320)
        #expect(frames.count == 5)
        #expect(try decryptCommand(frames[0]) == [0x11, 5, 0x0B, 7, 0, 96, 0, 0x40, 1, 1, 0, 0])
        for (index, frame) in frames[1 ... 3].enumerated() {
            let data = try decryptCommand(frame)
            #expect(XiaomiPrinterProtocol.read16(data, 5) == index + 1)
            #expect(XiaomiPrinterProtocol.read16(data, 7) == 3)
            #expect(data.count - 16 <= 1800)
            #expect(data.dropFirst(16).allSatisfy { $0 == 0x55 })
        }
        #expect(try decryptCommand(frames[4]) == [0x11, 5, 0x0C, 9, 0, 1, 2, 0, 0, 0, 2, 1, 0, 0])
        #expect(throws: XiaomiPrinterProtocol.Failure.invalidRaster) {
            try XiaomiPrinterProtocol.printFrames(raster: Data(), rows: 320)
        }
    }

    private func decryptCommand(_ data: Data) throws -> [UInt8] {
        let bytes = [UInt8](data)
        let plain = try XiaomiPrinterProtocol.crypt(Array(bytes[4 ..< (4 + XiaomiPrinterProtocol.read16(bytes, 2))]), decrypt: true)
        return Array(plain.prefix(XiaomiPrinterProtocol.read16(plain, 3) + 5))
    }
}

#if canImport(CoreBluetooth)
    @Suite("Xiaomi Printer Discovery Tests")
    @MainActor
    struct XiaomiPrinterDiscoveryTests {
        @Test("Matches the printer by advertised name")
        func matchesName() {
            #expect(XiaomiLabelPrinterAdapter.matches(name: "xiaomi.printer", advertisementData: [:]))
            #expect(!XiaomiLabelPrinterAdapter.matches(name: "Mi Band", advertisementData: [:]))
        }
    }
#endif

@Suite("Label Bitmap Tests")
struct LabelBitmapTests {
    @Test("Horizontal label maps bottom row to head column 0")
    func horizontal() throws {
        // 16 dots long, 96 tall; black pixel at top-left and bottom-left.
        let image = try makeImage(width: 16, height: 96, black: [(0, 0), (0, 95)])
        let bitmap = try LabelBitmap(image: image, headDots: 96)
        #expect(bitmap.rows == 16)
        #expect(bitmap.data.count == 16 * 12)
        let row0 = [UInt8](bitmap.data.prefix(12))
        #expect(row0[0] == 0x80) // bottom-left → column 0
        #expect(row0[11] == 0x01) // top-left → column 95
        #expect(bitmap.data.dropFirst(12).allSatisfy { $0 == 0 })
    }

    @Test("Vertical label length follows image height")
    func vertical() throws {
        // 96 wide, 40 tall; black pixel at bottom-right (last row printed first after rotation).
        let image = try makeImage(width: 96, height: 40, black: [(95, 39)])
        let bitmap = try LabelBitmap(image: image, headDots: 96)
        #expect(bitmap.rows == 40)
        #expect([UInt8](bitmap.data.prefix(12))[0] == 0x80)
        #expect(bitmap.data.dropFirst(1).allSatisfy { $0 == 0 })
    }

    @Test("Rejects images without a head-width side")
    func invalidSize() throws {
        let image = try makeImage(width: 50, height: 50, black: [])
        #expect(throws: LabelBitmap.Failure.invalidSize(width: 50, height: 50, headDots: 96)) {
            try LabelBitmap(image: image, headDots: 96)
        }
    }

    @Test("Length in millimeters uses printer resolution")
    func length() throws {
        let bitmap = try LabelBitmap(image: makeImage(width: 320, height: 96, black: []), headDots: 96)
        #expect(bitmap.lengthInMillimeters(dotsPerMillimeter: 8) == 40)
    }

    /// Builds a white grayscale image with black pixels at (x, y), y measured from the top
    private func makeImage(width: Int, height: Int, black: [(Int, Int)]) throws -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height)
        for (x, y) in black {
            pixels[y * width + x] = 0
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        return try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }
}

private func hex(_ string: String) -> [UInt8] {
    stride(from: 0, to: string.count, by: 2).map { offset in
        let start = string.index(string.startIndex, offsetBy: offset)
        return UInt8(string[start ..< string.index(start, offsetBy: 2)], radix: 16)!
    }
}
