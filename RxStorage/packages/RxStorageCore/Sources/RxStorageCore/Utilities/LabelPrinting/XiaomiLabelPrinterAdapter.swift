//
//  XiaomiLabelPrinterAdapter.swift
//  RxStorageCore
//
//  Label printer adapter for the Xiaomi label printer (xiaomi.printer)
//

#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Foundation
    import Logging

    /// Drives the Xiaomi label printer over its FE95 GATT service.
    ///
    /// Commands go to characteristic 001F (write without response) and status arrives as
    /// notifications on 0020. Firmware is read from 0004.
    @MainActor
    @Observable
    public final class XiaomiLabelPrinterAdapter: NSObject, LabelPrinterAdapter {
        public static let modelName = "Xiaomi Label Printer"
        public static let headDots = XiaomiPrinterProtocol.width
        public static let dotsPerMillimeter = 8.0

        private static let serviceID = CBUUID(string: "FE95")
        private static let txID = CBUUID(string: "001F")
        private static let rxID = CBUUID(string: "0020")
        private static let firmwareID = CBUUID(string: "0004")
        /// MiBeacon product ID broadcast in FE95 service data (bytes 2–3, little endian)
        private static let productID: UInt16 = 0x34FE

        public let peripheral: CBPeripheral
        public private(set) var status = LabelPrinterStatus()

        @ObservationIgnored private var tx: CBCharacteristic?
        @ObservationIgnored private var rx: CBCharacteristic?
        @ObservationIgnored private var stream = XiaomiPacketStream()
        @ObservationIgnored private var state = XiaomiPrinterState()
        @ObservationIgnored private var isSubscribed = false
        @ObservationIgnored private var isDisconnected = false
        @ObservationIgnored private var setupError: Error?
        @ObservationIgnored private var lastLoggedRX: Data?
        @ObservationIgnored private var statusSerial = 0
        @ObservationIgnored private var completionSerial = 0
        @ObservationIgnored private var printingCycleSerial = 0
        @ObservationIgnored private var writesSincePause = 0
        @ObservationIgnored private let logger = Logger(label: "com.rxlab.rxstorage.XiaomiLabelPrinter")

        public static func matches(name: String?, advertisementData: [String: Any]) -> Bool {
            let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? name ?? ""
            if advertisedName.localizedCaseInsensitiveContains("xiaomi.printer") {
                return true
            }
            // The printer advertises FE95 service data without a service UUID list.
            guard let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
                  let beacon = serviceData[serviceID], beacon.count >= 4
            else { return false }
            let bytes = [UInt8](beacon)
            return UInt16(bytes[2]) | UInt16(bytes[3]) << 8 == productID
        }

        public required init(peripheral: CBPeripheral) {
            self.peripheral = peripheral
            super.init()
            peripheral.delegate = self
        }

        // MARK: - LabelPrinterAdapter

        public func prepare() async throws {
            peripheral.discoverServices([Self.serviceID])
            try await waitUntil(timeout: 15, explanation: "Timed out while discovering printer services.") {
                isSubscribed
            }
            try await send(XiaomiPrinterProtocol.connected())
            // The status query also starts the printer's periodic status broadcasts.
            try await query()
            logger.info("Protocol verified: valid CRC and printer status received")
        }

        public func refreshStatus() async throws {
            try await query()
        }

        public func printLabel(_ bitmap: LabelBitmap, progress: @escaping @MainActor (Double) -> Void) async throws {
            guard bitmap.headDots == Self.headDots else {
                throw LabelPrinterError.unsupported("This label is \(bitmap.headDots) dots wide but the printer needs \(Self.headDots).")
            }
            progress(0)
            try await query()
            try ensureNoFaults()
            guard !state.printing else { throw LabelPrinterError.busy }

            let frames = try XiaomiPrinterProtocol.printFrames(raster: bitmap.data, rows: bitmap.rows)
            let previousCompletion = completionSerial
            let previousPrintCycle = printingCycleSerial
            logger.info("PRINT: \(bitmap.headDots) × \(bitmap.rows) dots, \(bitmap.data.count) raster bytes")
            writesSincePause = 0
            for (index, frame) in frames.enumerated() {
                try await waitForBuffer()
                try ensureNoFaults()
                try await send(frame)
                progress(Double(index + 1) / Double(frames.count))
            }

            try await waitUntil(timeout: 60, explanation: "Label sent, but the printer did not acknowledge it. Check the label before printing again.") {
                completionSerial > previousCompletion || !state.faults.isEmpty
            }
            try ensureNoFaults()
            try await waitUntil(timeout: 60, explanation: "The printer accepted the label but did not report finishing. Check the label before printing again.") {
                (printingCycleSerial > previousPrintCycle && !state.printing) || !state.faults.isEmpty
            }
            try ensureNoFaults()
            logger.info("SUCCESS: printer acknowledged the job, printed, and returned to idle")
        }

        public func handleDisconnect() {
            isDisconnected = true
            tx = nil
            rx = nil
            isSubscribed = false
        }

        // MARK: - Transport

        private func ensureNoFaults() throws {
            if !state.faults.isEmpty {
                throw LabelPrinterError.fault(state.faults.joined(separator: ", "))
            }
        }

        private func send(_ frame: Data) async throws {
            guard let tx, peripheral.state == .connected else { throw LabelPrinterError.disconnected }
            let maximum = min(204, peripheral.maximumWriteValueLength(for: .withoutResponse))
            guard maximum > 0 else { throw LabelPrinterError.unsupported("Bluetooth returned an invalid write limit.") }
            logger.debug("TX \(frame.count) bytes: \(frame.prefix(48).hexString)\(frame.count > 48 ? " …" : "")")
            for offset in stride(from: 0, to: frame.count, by: maximum) {
                try Task.checkCancellation()
                // The printer drops data if written too quickly; pause every few packets.
                if writesSincePause >= 3 {
                    try await Task.sleep(for: .milliseconds(90))
                    writesSincePause = 0
                }
                let deadline = Date().addingTimeInterval(10)
                while !peripheral.canSendWriteWithoutResponse {
                    try Task.checkCancellation()
                    guard peripheral.state == .connected else { throw LabelPrinterError.disconnected }
                    guard Date() < deadline else { throw LabelPrinterError.timeout("Bluetooth write queue timed out.") }
                    try await Task.sleep(for: .milliseconds(10))
                }
                guard peripheral.state == .connected else { throw LabelPrinterError.disconnected }
                peripheral.writeValue(frame.subdata(in: offset ..< min(offset + maximum, frame.count)), for: tx, type: .withoutResponse)
                writesSincePause += 1
            }
        }

        private func waitUntil(timeout: TimeInterval, explanation: String, predicate: () -> Bool) async throws {
            let deadline = Date().addingTimeInterval(timeout)
            while !predicate() {
                try Task.checkCancellation()
                if let setupError { throw setupError }
                guard !isDisconnected else { throw LabelPrinterError.disconnected }
                guard Date() < deadline else { throw LabelPrinterError.timeout(explanation) }
                try await Task.sleep(for: .milliseconds(50))
            }
        }

        private func query() async throws {
            let serial = statusSerial
            try await send(XiaomiPrinterProtocol.statusQuery())
            try await waitUntil(timeout: 12, explanation: "The printer did not report its status. Turn it off and on, then refresh.") {
                statusSerial > serial
            }
        }

        private func waitForBuffer() async throws {
            let deadline = Date().addingTimeInterval(30)
            while (state.bufferFree ?? 0) <= 500 {
                guard Date() < deadline else { throw LabelPrinterError.timeout("The printer buffer did not become available.") }
                try await query()
                try ensureNoFaults()
                try await Task.sleep(for: .milliseconds(200))
            }
        }

        private func publishStatus() {
            var next = status
            next.batteryLevel = state.battery ?? status.batteryLevel
            next.faults = state.faults
            next.isPrinting = state.printing
            if next != status { status = next }
        }

        private func fail(_ error: Error) {
            logger.error("Setup failed: \(error.localizedDescription)")
            setupError = error
        }
    }

    // MARK: - CBPeripheralDelegate

    extension XiaomiLabelPrinterAdapter: @preconcurrency CBPeripheralDelegate {
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error { return fail(error) }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else {
                return fail(LabelPrinterError.unsupported("The FE95 printer service is missing. This printer is not supported."))
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }

        public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let error { return fail(error) }
            for characteristic in service.characteristics ?? [] {
                logger.debug("Characteristic \(characteristic.uuid.uuidString), properties \(characteristic.properties.rawValue)")
                if characteristic.uuid == Self.txID { tx = characteristic }
                if characteristic.uuid == Self.rxID { rx = characteristic }
                if characteristic.uuid == Self.firmwareID, characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
            guard let tx, tx.properties.contains(.writeWithoutResponse), let rx, rx.properties.contains(.notify) else {
                return fail(LabelPrinterError.unsupported("Required printer characteristics 001F / 0020 were not found."))
            }
            peripheral.setNotifyValue(true, for: rx)
        }

        public func peripheral(_: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            guard characteristic.uuid == Self.rxID else { return }
            if let error { return fail(error) }
            isSubscribed = characteristic.isNotifying
        }

        public func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let error {
                logger.warning("Read error: \(error.localizedDescription)")
                return
            }
            guard let value = characteristic.value else { return }
            if characteristic.uuid == Self.firmwareID {
                status.firmwareVersion = String(bytes: value.prefix(while: { $0 != 0 }), encoding: .utf8) ?? value.hexString
                return
            }
            guard characteristic.uuid == Self.rxID else { return }
            if value != lastLoggedRX {
                logger.debug("RX \(value.hexString)")
                lastLoggedRX = value
            }
            for packet in stream.append(value) {
                let wasPrinting = state.printing
                state.consume(packet)
                if !wasPrinting, state.printing { printingCycleSerial += 1 }
                if XiaomiPrinterState.isStatusPacket(packet), state.hasStatus { statusSerial += 1 }
                if XiaomiPrinterState.isPrintAcknowledgement(packet) { completionSerial += 1 }
            }
            publishStatus()
        }
    }
#endif
