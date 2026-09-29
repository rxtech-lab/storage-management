//
//  XiaomiPrinterProtocol.swift
//  RxStorageCore
//
//  Wire format for the Xiaomi label printer (xiaomi.printer, BLE service FE95).
//  Documented by jasiek/xiaomi-mjbqdyj1-wc-reveng, FINDINGS.md and verified
//  against captured hardware sessions.
//

import CommonCrypto
import Foundation

/// Packet encoding and decoding for the Xiaomi label printer
enum XiaomiPrinterProtocol {
    /// Print head width in dots (12 mm at 8 dots/mm)
    static let width = 96
    static let rasterChunkSize = 1800
    static let key: [UInt8] = [0x99, 0xB8, 0x29, 0x43, 0x6C, 0xDD, 0x56, 0x47, 0xAA, 0xDB, 0x88, 0x16, 0xF7, 0x3E, 0x86, 0x44]
    static let iv: [UInt8] = [0x00, 0x01, 0x02, 0x0F, 0x3C, 0xF8, 0x99, 0xAB, 0xAB, 0xCD, 0x25, 0x31, 0x8D, 0xF4, 0x46, 0xB1]

    enum Failure: LocalizedError, Equatable {
        case crypto(Int32)
        case invalidFrame
        case invalidRaster

        var errorDescription: String? {
            switch self {
            case let .crypto(status): "Encryption failed (\(status))."
            case .invalidFrame: "Invalid printer packet or checksum."
            case .invalidRaster: "Label must contain 12 bytes per row and fit in 65535 rows."
            }
        }
    }

    static func le16(_ value: Int) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
    }

    static func le32(_ value: UInt32) -> [UInt8] {
        (0 ..< 4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    static func read16(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    static func read32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (0 ..< 4).reduce(0) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
    }

    /// CRC32 with the printer's custom seed
    static func crc(_ bytes: [UInt8]) -> UInt32 {
        var register: UInt32 = ~0x7695_3521
        for byte in bytes {
            register ^= UInt32(byte)
            for _ in 0 ..< 8 {
                register = (register >> 1) ^ ((register & 1) == 1 ? 0xEDB8_8320 : 0)
            }
        }
        return ~register
    }

    /// AES-128-CBC without padding
    static func crypt(_ input: [UInt8], decrypt: Bool = false) throws -> [UInt8] {
        guard !input.isEmpty, input.count % 16 == 0 else { throw Failure.invalidFrame }
        var output = [UInt8](repeating: 0, count: input.count + 16)
        var written = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { source in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                            0, keyBytes.baseAddress, key.count, ivBytes.baseAddress,
                            source.baseAddress, input.count, out.baseAddress, capacity, &written
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw Failure.crypto(status) }
        return Array(output.prefix(written))
    }

    /// Wraps a payload in an encrypted frame: A3 20 | len | AES(payload) | CRC
    static func frame(_ payload: [UInt8]) throws -> Data {
        var padded = payload
        padded += Array(repeating: 0, count: (16 - padded.count % 16) % 16)
        let encrypted = try crypt(padded)
        return Data([0xA3, 0x20] + le16(encrypted.count) + encrypted + le32(crc(encrypted)))
    }

    /// Decodes a printer frame (plain `A3 00` or encrypted `A3 20`) into its payload
    static func decode(_ frame: [UInt8]) throws -> [UInt8] {
        guard frame.count >= 8, frame[0] == 0xA3, [0x00, 0x20].contains(frame[1]) else {
            throw Failure.invalidFrame
        }
        let length = read16(frame, 2)
        guard length > 0, frame.count == length + 8 else { throw Failure.invalidFrame }
        let body = Array(frame[4 ..< (4 + length)])
        guard read32(frame, 4 + length) == crc(body) else { throw Failure.invalidFrame }
        let plain = try frame[1] == 0x20 ? crypt(body, decrypt: true) : body
        guard plain.count >= 5, [0x10, 0x21].contains(plain[0]),
              read16(plain, 3) + 5 <= plain.count
        else { throw Failure.invalidFrame }
        return Array(plain.prefix(read16(plain, 3) + 5))
    }

    static func command(_ group: UInt8, _ command: UInt8, _ body: [UInt8] = []) throws -> Data {
        try frame([0x11, group, command] + le16(body.count) + body)
    }

    static func statusQuery() throws -> Data {
        try command(1, 0x13)
    }

    static func connected() throws -> Data {
        try command(1, 0x1E, [1])
    }

    /// Builds the start, raster chunk, and end frames for one label
    static func printFrames(raster: Data, rows: Int) throws -> [Data] {
        guard rows > 0, rows <= 65535, raster.count == rows * (width / 8) else { throw Failure.invalidRaster }
        var frames = try [command(5, 0x0B, le16(width) + le16(rows) + [1, 0, 0])]
        let bytes = [UInt8](raster)
        let count = (bytes.count + rasterChunkSize - 1) / rasterChunkSize
        for index in 0 ..< count {
            let chunk = Array(bytes[(index * rasterChunkSize) ..< min(bytes.count, (index + 1) * rasterChunkSize)])
            let body = le16(index + 1) + le16(count) + [0x10, 0x0C, 0, 0, 0, 0, 0] + chunk
            try frames.append(command(5, 0x0D, body))
        }
        try frames.append(command(5, 0x0C, [1, 2, 0, 0, 0, 2, 1, 0, 0]))
        return frames
    }
}

// MARK: - Packet Stream

/// Reassembles notification fragments into decoded printer payloads
struct XiaomiPacketStream {
    private var bytes: [UInt8] = []

    mutating func append(_ fragment: Data) -> [[UInt8]] {
        bytes += fragment
        var packets: [[UInt8]] = []
        while bytes.count >= 4 {
            guard bytes[0] == 0xA3, [0x00, 0x20].contains(bytes[1]) else {
                bytes.removeFirst()
                continue
            }
            let length = XiaomiPrinterProtocol.read16(bytes, 2)
            guard length > 0, length <= 4096, bytes[1] != 0x20 || length % 16 == 0 else {
                bytes.removeFirst()
                continue
            }
            guard bytes.count >= length + 8 else { break }
            if let packet = try? XiaomiPrinterProtocol.decode(Array(bytes.prefix(length + 8))) {
                packets.append(packet)
                bytes.removeFirst(length + 8)
            } else {
                bytes.removeFirst()
            }
        }
        return packets
    }
}

// MARK: - Printer State

/// Status parsed from printer notifications
struct XiaomiPrinterState {
    var bufferFree: UInt32?
    var flagsA: UInt8?
    var flagsB: UInt8?
    var battery: Int?
    var hasStatus = false

    var printing: Bool {
        (flagsA ?? 0) & 0x80 != 0
    }

    var faults: [String] {
        let a = ["Cover open", "No paper", "Paper jam", "Print head hot", "Print head missing", "High voltage", "Low voltage"]
        let b = ["Cutter error", "Font error", "Memory error", "Paper calibration needed", "Powering off", "Shutdown in progress", "Battery hot"]
        return a.enumerated().compactMap { (flagsA ?? 0) & (1 << $0.offset) != 0 ? $0.element : nil }
            + b.enumerated().compactMap { (flagsB ?? 0) & (1 << $0.offset) != 0 ? $0.element : nil }
    }

    /// Whether this payload is a status report (group 1, commands 1F/12/13)
    static func isStatusPacket(_ payload: [UInt8]) -> Bool {
        payload.count >= 3 && payload[1] == 1 && [0x1F, 0x12, 0x13].contains(payload[2])
    }

    /// Whether this payload acknowledges a completed print job
    static func isPrintAcknowledgement(_ payload: [UInt8]) -> Bool {
        payload.count >= 3 && payload[1] == 5 && payload[2] == 0x0C
    }

    mutating func consume(_ payload: [UInt8]) {
        guard payload.count >= 5, payload[1] == 1 else { return }
        if payload[2] == 0x1F {
            // Periodic broadcasts use TLVs: type(1), length(LE16), value.
            // Battery TLV is `03 01 00 xx`: one byte, percent.
            var offset = 5
            while offset + 3 <= payload.count {
                let tag = payload[offset]
                let count = XiaomiPrinterProtocol.read16(payload, offset + 1)
                let start = offset + 3
                guard count > 0, start + count <= payload.count else { return }
                if tag == 1, count == 4 { bufferFree = XiaomiPrinterProtocol.read32(payload, start) }
                if tag == 2, count >= 2 {
                    flagsA = payload[start]
                    flagsB = payload[start + 1]
                    hasStatus = true
                }
                if tag == 3, count == 1, payload[start] <= 100 { battery = Int(payload[start]) }
                offset = start + count
            }
        } else if [0x12, 0x13].contains(payload[2]) {
            var offset = 5
            while offset + 3 <= payload.count {
                let count = XiaomiPrinterProtocol.read16(payload, offset + 1)
                let start = offset + 3
                guard count > 0, start + count <= payload.count else { return }
                if payload[offset] == 1, count == 4 {
                    flagsA = payload[start]
                    flagsB = payload[start + 1]
                    hasStatus = true
                }
                offset = start + count
            }
        }
    }
}

extension Data {
    /// Space-separated uppercase hex, used for printer debug logging
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
