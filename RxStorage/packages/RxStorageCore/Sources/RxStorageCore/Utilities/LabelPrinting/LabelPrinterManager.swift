//
//  LabelPrinterManager.swift
//  RxStorageCore
//
//  Bluetooth discovery and connection for label printers
//

#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Foundation
    import Logging

    /// A supported label printer found while scanning
    public struct DiscoveredLabelPrinter: Identifiable {
        public let id: UUID
        public let name: String
        public let modelName: String
        let peripheral: CBPeripheral
        let adapterType: any LabelPrinterAdapter.Type
    }

    /// Scans for supported label printers, auto-connects to the first one found, and prints labels.
    @MainActor
    @Observable
    public final class LabelPrinterManager: NSObject {
        public enum ConnectionState: Equatable {
            case idle
            case unavailable(String)
            case scanning
            case notFound
            case connecting(String)
            case connected
            case failed(String)
        }

        /// Printer adapters, checked in order against each advertisement
        public static let supportedAdapters: [any LabelPrinterAdapter.Type] = [XiaomiLabelPrinterAdapter.self]

        public private(set) var printers: [DiscoveredLabelPrinter] = []
        public private(set) var state: ConnectionState = .idle
        /// Adapter for the connected (or connecting) printer
        public private(set) var adapter: (any LabelPrinterAdapter)?
        public private(set) var isPrinting = false
        public private(set) var printProgress = 0.0

        public var connectedPrinterID: UUID? {
            adapter?.peripheral.identifier
        }

        public var isConnected: Bool {
            state == .connected
        }

        @ObservationIgnored private var central: CBCentralManager?
        @ObservationIgnored private var wantsScan = false
        @ObservationIgnored private var autoConnect = true
        @ObservationIgnored private var scanTimeout: Task<Void, Never>?
        @ObservationIgnored private var connectTimeout: Task<Void, Never>?
        @ObservationIgnored private var setupTask: Task<Void, Never>?
        @ObservationIgnored private let logger = Logger(label: "com.rxlab.rxstorage.LabelPrinterManager")
        private static let scanDuration: Duration = .seconds(15)
        private static let connectDuration: Duration = .seconds(20)

        override public init() {
            super.init()
        }

        // MARK: - Public API

        /// Starts scanning and auto-connects to the first supported printer found
        public func start() {
            guard adapter == nil else { return }
            wantsScan = true
            autoConnect = true
            guard let central else {
                // Scanning starts from centralManagerDidUpdateState once Bluetooth is ready.
                central = CBCentralManager(delegate: self, queue: .main)
                return
            }
            applyBluetoothState(central.state)
        }

        /// Drops the current connection and scans again
        public func refresh() {
            disconnect()
            printers = []
            start()
        }

        /// Stops scanning and disconnects
        public func stop() {
            wantsScan = false
            disconnect()
            state = .idle
        }

        /// Connects to a printer chosen by the user
        public func connect(to printerID: UUID) {
            guard printerID != connectedPrinterID,
                  let printer = printers.first(where: { $0.id == printerID }),
                  let central
            else { return }
            disconnect()
            stopScan()
            autoConnect = false
            state = .connecting(printer.name)
            logger.info("Connecting to \(printer.name) (\(printer.modelName))")
            adapter = printer.adapterType.init(peripheral: printer.peripheral)
            central.connect(printer.peripheral)
            connectTimeout = Task { [weak self] in
                do { try await Task.sleep(for: Self.connectDuration) } catch { return }
                guard let self, case .connecting = self.state else { return }
                self.disconnect()
                self.state = .failed("Connection timed out. Close other apps using the printer, then refresh.")
            }
        }

        /// Refreshes battery and fault status from the connected printer
        public func refreshStatus() async {
            guard let adapter, isConnected, !isPrinting else { return }
            do {
                try await adapter.refreshStatus()
            } catch {
                logger.warning("Status refresh failed: \(error.localizedDescription)")
            }
        }

        /// Prints a label on the connected printer
        public func print(_ bitmap: LabelBitmap) async throws {
            guard let adapter, isConnected else { throw LabelPrinterError.disconnected }
            guard !isPrinting else { throw LabelPrinterError.busy }
            isPrinting = true
            printProgress = 0
            defer { isPrinting = false }
            try await adapter.printLabel(bitmap) { [weak self] progress in
                self?.printProgress = progress
            }
        }

        // MARK: - Connection

        private func beginScan() {
            guard let central, !central.isScanning else { return }
            state = .scanning
            // The Xiaomi printer advertises FE95 service data but no service UUID list,
            // and its name may only arrive in a later scan response, so allow duplicates.
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            scanTimeout?.cancel()
            scanTimeout = Task { [weak self] in
                do { try await Task.sleep(for: Self.scanDuration) } catch { return }
                guard let self, self.state == .scanning else { return }
                self.stopScan()
                self.state = self.printers.isEmpty ? .notFound : .idle
            }
        }

        private func stopScan() {
            scanTimeout?.cancel()
            scanTimeout = nil
            if central?.isScanning == true { central?.stopScan() }
        }

        private func disconnect() {
            setupTask?.cancel()
            setupTask = nil
            connectTimeout?.cancel()
            connectTimeout = nil
            stopScan()
            if let adapter {
                adapter.handleDisconnect()
                central?.cancelPeripheralConnection(adapter.peripheral)
            }
            adapter = nil
        }

        private func applyBluetoothState(_ bluetoothState: CBManagerState) {
            switch bluetoothState {
            case .poweredOn:
                if wantsScan, adapter == nil { beginScan() }
            case .unauthorized:
                disconnect()
                state = .unavailable("Allow Bluetooth access for RxStorage in Settings.")
            case .poweredOff:
                disconnect()
                state = .unavailable("Turn on Bluetooth to connect a label printer.")
            case .unsupported:
                disconnect()
                state = .unavailable("Bluetooth is not available on this device.")
            default:
                break
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    extension LabelPrinterManager: @preconcurrency CBCentralManagerDelegate {
        public func centralManagerDidUpdateState(_ central: CBCentralManager) {
            logger.info("Bluetooth state: \(central.state.rawValue)")
            applyBluetoothState(central.state)
        }

        public func centralManager(
            _: CBCentralManager, didDiscover peripheral: CBPeripheral,
            advertisementData: [String: Any], rssi _: NSNumber
        ) {
            guard !printers.contains(where: { $0.id == peripheral.identifier }),
                  let adapterType = Self.supportedAdapters.first(where: {
                      $0.matches(name: peripheral.name, advertisementData: advertisementData)
                  })
            else { return }

            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? adapterType.modelName
            let printer = DiscoveredLabelPrinter(
                id: peripheral.identifier, name: name, modelName: adapterType.modelName,
                peripheral: peripheral, adapterType: adapterType
            )
            printers.append(printer)
            logger.info("Found \(name) (\(adapterType.modelName))")

            if autoConnect, adapter == nil {
                connect(to: printer.id)
            }
        }

        public func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
            guard let adapter, adapter.peripheral === peripheral else { return }
            logger.info("Connected, preparing printer")
            setupTask = Task { [weak self] in
                do {
                    try await adapter.prepare()
                    guard let self, self.adapter === adapter else { return }
                    self.connectTimeout?.cancel()
                    self.state = .connected
                } catch {
                    guard let self, self.adapter === adapter, !(error is CancellationError) else { return }
                    self.disconnect()
                    self.state = .failed(error.localizedDescription)
                }
            }
        }

        public func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            guard adapter?.peripheral === peripheral else { return }
            disconnect()
            state = .failed(error?.localizedDescription ?? "Could not connect to the printer.")
        }

        public func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            guard adapter?.peripheral === peripheral else { return }
            logger.info("Printer disconnected: \(error?.localizedDescription ?? "no error")")
            disconnect()
            state = .failed(error?.localizedDescription ?? "The printer disconnected.")
        }
    }
#endif
