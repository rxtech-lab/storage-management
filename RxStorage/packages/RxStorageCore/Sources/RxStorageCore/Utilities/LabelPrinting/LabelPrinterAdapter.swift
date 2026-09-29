//
//  LabelPrinterAdapter.swift
//  RxStorageCore
//
//  Adapter protocol for Bluetooth label printers
//

#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Foundation

    /// Live status reported by a connected label printer
    public struct LabelPrinterStatus: Sendable, Equatable {
        /// Battery level in percent, if the printer reports it
        public var batteryLevel: Int?
        /// Firmware version string, if the printer reports it
        public var firmwareVersion: String?
        /// Human-readable fault descriptions (cover open, no paper, …)
        public var faults: [String] = []
        /// Whether the printer is currently printing
        public var isPrinting = false

        public init(batteryLevel: Int? = nil, firmwareVersion: String? = nil, faults: [String] = [], isPrinting: Bool = false) {
            self.batteryLevel = batteryLevel
            self.firmwareVersion = firmwareVersion
            self.faults = faults
            self.isPrinting = isPrinting
        }
    }

    /// Errors raised by label printer adapters
    public enum LabelPrinterError: LocalizedError, Equatable {
        case disconnected
        case timeout(String)
        case fault(String)
        case unsupported(String)
        case busy

        public var errorDescription: String? {
            switch self {
            case .disconnected: "The printer disconnected."
            case let .timeout(message): message
            case let .fault(message): message
            case let .unsupported(message): message
            case .busy: "The printer is busy. Wait for the current job to finish."
            }
        }
    }

    /// A driver for one family of Bluetooth label printers.
    ///
    /// `LabelPrinterManager` owns Bluetooth scanning and the central connection. Each adapter
    /// recognizes its printers from advertisements, then handles the GATT session, status, and
    /// printing once the peripheral is connected. Add a new printer model by implementing this
    /// protocol and registering the type in `LabelPrinterManager.supportedAdapters`.
    @MainActor
    public protocol LabelPrinterAdapter: AnyObject {
        /// Display name for the printer model
        static var modelName: String { get }
        /// Print head width in dots
        static var headDots: Int { get }
        /// Print resolution along and across the tape
        static var dotsPerMillimeter: Double { get }

        /// Whether an advertising peripheral is a printer this adapter drives
        static func matches(name: String?, advertisementData: [String: Any]) -> Bool

        /// Creates an adapter for a discovered peripheral. The adapter becomes the peripheral's delegate.
        init(peripheral: CBPeripheral)

        var peripheral: CBPeripheral { get }
        /// Latest status. Implementations should be `@Observable` so UI updates live.
        var status: LabelPrinterStatus { get }

        /// Runs the protocol handshake after the central connects. Throws if the printer is incompatible.
        func prepare() async throws
        /// Requests a fresh status report
        func refreshStatus() async throws
        /// Prints one label, reporting transfer progress from 0 to 1
        func printLabel(_ bitmap: LabelBitmap, progress: @escaping @MainActor (Double) -> Void) async throws
        /// Called when the central loses the connection
        func handleDisconnect()
    }
#endif
