//
//  LabelPrinterControls.swift
//  RxStorage
//
//  Form rows for picking, connecting, and monitoring a Bluetooth label printer
//

import RxStorageCore
import SwiftUI

/// Printer picker, connection status, and printer details rows.
/// Pair with `labelPrintProgressOverlay(_:)` to show print progress.
/// Place inside a `Section`; the owner is responsible for starting and stopping the manager.
struct LabelPrinterControls: View {
    let printerManager: LabelPrinterManager
    /// Shows a "Label printed" confirmation when not printing
    var didPrint = false

    var body: some View {
        if !printerManager.printers.isEmpty {
            Picker("Printer", selection: printerSelection) {
                if printerManager.connectedPrinterID == nil {
                    Text("Select").tag(UUID?.none)
                }
                ForEach(printerManager.printers) { printer in
                    Text(printer.name).tag(UUID?.some(printer.id))
                }
            }
            .disabled(printerManager.isPrinting)
        }

        connectionRow

        if printerManager.isConnected, let adapter = printerManager.adapter {
            LabeledContent("Model", value: type(of: adapter).modelName)
            LabeledContent("Battery") {
                if let battery = adapter.status.batteryLevel {
                    Label("\(battery)%", systemImage: batteryIcon(battery))
                } else {
                    Text("Unknown")
                }
            }
            LabeledContent("Firmware", value: adapter.status.firmwareVersion ?? "Unknown")
            if !adapter.status.faults.isEmpty {
                Label(adapter.status.faults.joined(separator: ", "), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }

        if didPrint, !printerManager.isPrinting {
            Label("Label printed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private var connectionRow: some View {
        HStack {
            Label(connectionTitle, systemImage: connectionIcon)
                .foregroundStyle(connectionColor)
            Spacer()
            switch printerManager.state {
            case .scanning, .connecting:
                ProgressView()
            case .connected:
                Button {
                    Task { await printerManager.refreshStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(printerManager.isPrinting)
                .accessibilityLabel("Refresh printer status")
            default:
                Button {
                    printerManager.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("label-printer-refresh")
            }
        }
    }

    private var printerSelection: Binding<UUID?> {
        Binding(
            get: { printerManager.connectedPrinterID },
            set: { id in
                if let id { printerManager.connect(to: id) }
            }
        )
    }

    private var connectionTitle: String {
        switch printerManager.state {
        case .idle: "Not connected"
        case let .unavailable(message): message
        case .scanning: "Searching for printers…"
        case .notFound: "No printer found. Turn on the printer and refresh."
        case let .connecting(name): "Connecting to \(name)…"
        case .connected: "Connected"
        case let .failed(message): message
        }
    }

    private var connectionIcon: String {
        switch printerManager.state {
        case .connected: "checkmark.circle.fill"
        case .scanning, .connecting: "antenna.radiowaves.left.and.right"
        case .unavailable, .failed: "exclamationmark.triangle.fill"
        case .idle, .notFound: "printer"
        }
    }

    private var connectionColor: Color {
        switch printerManager.state {
        case .connected: .green
        case .unavailable, .failed: .orange
        default: .secondary
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

// MARK: - Print Progress Overlay

/// Dims the content and shows a progress card while a label is printing
private struct LabelPrintProgressOverlay: ViewModifier {
    let printerManager: LabelPrinterManager

    /// Spelled out because RxStorageCore's `Content` model shadows `ViewModifier.Content`
    func body(content: _ViewModifier_Content<Self>) -> some View {
        content
            .overlay {
                if printerManager.isPrinting {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            Image(systemName: "printer.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                                .symbolEffect(.pulse)
                            Text("Printing Label…")
                                .font(.headline)
                            ProgressView(value: printerManager.printProgress)
                                .frame(width: 180)
                            Text(printerManager.printProgress, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("label-print-progress")
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: printerManager.isPrinting)
            .interactiveDismissDisabled(printerManager.isPrinting)
    }
}

extension View {
    /// Shows a blocking progress overlay while `printerManager` is printing
    func labelPrintProgressOverlay(_ printerManager: LabelPrinterManager) -> some View {
        modifier(LabelPrintProgressOverlay(printerManager: printerManager))
    }
}
