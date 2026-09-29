//
//  LabelPrintSheet.swift
//  RxStorage
//
//  Preview, configure, and print an item label on a Bluetooth label printer
//

import RxStorageCore
import SwiftUI

/// Sheet that previews an item label and prints it on a connected Bluetooth label printer
struct LabelPrintSheet: View {
    let item: StorageItemDetail

    @State private var printerManager = LabelPrinterManager()
    @State private var bitmap: LabelBitmap?
    @State private var printError: Error?
    @State private var didPrint = false
    @AppStorage("labelPrint.showTitle") private var showTitle = true
    @AppStorage("labelPrint.showDescription") private var showDescription = false
    @AppStorage("labelPrint.showDate") private var showDate = false
    @AppStorage("labelPrint.showLocation") private var showLocation = false
    @AppStorage("labelPrint.orientation") private var orientation: LabelOrientation = .horizontal
    @Environment(\.dismiss) private var dismiss

    private var options: LabelPrintOptions {
        LabelPrintOptions(
            showTitle: showTitle,
            showDescription: showDescription,
            showDate: showDate,
            showLocation: showLocation,
            orientation: orientation
        )
    }

    /// Adapter type of the connected printer, or the default model before connecting
    private var printerType: any LabelPrinterAdapter.Type {
        printerManager.adapter.map { type(of: $0) } ?? LabelPrinterManager.supportedAdapters[0]
    }

    private var layoutView: LabelPrintLayoutView {
        LabelPrintLayoutView(
            item: item,
            options: options,
            headDots: printerType.headDots,
            dotsPerMillimeter: printerType.dotsPerMillimeter
        )
    }

    private var canPrint: Bool {
        printerManager.isConnected
            && !printerManager.isPrinting
            && bitmap != nil
            && options.hasContent
            && printerManager.adapter?.status.faults.isEmpty == true
    }

    var body: some View {
        NavigationStack {
            Form {
                printerSection
                previewSection
                fieldsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Print Label")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await printLabel() }
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                        .disabled(!canPrint)
                        .accessibilityIdentifier("label-print-button")
                    }
                }
                .onChange(of: options, initial: true) { renderPreview() }
                .onChange(of: printerType.headDots) { renderPreview() }
                .onAppear { printerManager.start() }
                .onDisappear { printerManager.stop() }
                .alert(
                    "Print Failed",
                    isPresented: Binding(get: { printError != nil }, set: { if !$0 { printError = nil } }),
                    presenting: printError
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { error in
                    Text(error.localizedDescription)
                }
        }
        .labelPrintProgressOverlay(printerManager)
        #if os(macOS)
            .frame(minWidth: 480, minHeight: 620)
        #endif
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section {
            if let bitmap, options.hasContent {
                Image(decorative: bitmap.preview, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .overlay(
                        Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .accessibilityLabel("Label preview")
            } else {
                ContentUnavailableView(
                    "Nothing to Print",
                    systemImage: "tag.slash",
                    description: Text("Turn on at least one field below.")
                )
            }
        } header: {
            Text("Preview")
        } footer: {
            if let bitmap, options.hasContent {
                let width = Double(printerType.headDots) / printerType.dotsPerMillimeter
                let length = bitmap.lengthInMillimeters(dotsPerMillimeter: printerType.dotsPerMillimeter)
                Text("\(Int(width)) × \(Int(length.rounded())) mm · length adjusts to the content")
            }
        }
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        Section("Content") {
            Toggle(isOn: $showTitle) {
                Label("Title", systemImage: "textformat")
            }
            Toggle(isOn: $showDescription) {
                Label("Description", systemImage: "text.alignleft")
            }
            .disabled(item.description?.isEmpty ?? true)
            Toggle(isOn: $showDate) {
                Label("Date", systemImage: "calendar")
            }
            Toggle(isOn: $showLocation) {
                Label("Location", systemImage: "mappin")
            }
            .disabled(item.location == nil)

            Picker("Orientation", selection: $orientation) {
                ForEach(LabelOrientation.allCases) { orientation in
                    Label(orientation.displayName, systemImage: orientation.icon).tag(orientation)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Printer

    private var printerSection: some View {
        Section {
            LabelPrinterControls(printerManager: printerManager, didPrint: didPrint)
        } header: {
            Text("Printer")
        } footer: {
            Text("Supported: \(LabelPrinterManager.supportedAdapters.map { $0.modelName }.joined(separator: ", "))")
        }
    }

    // MARK: - Actions

    private func renderPreview() {
        didPrint = false
        do {
            bitmap = try layoutView.renderBitmap()
        } catch {
            bitmap = nil
            printError = error
        }
    }

    private func printLabel() async {
        guard let bitmap else { return }
        didPrint = false
        do {
            try await printerManager.print(bitmap)
            didPrint = true
        } catch {
            printError = error
        }
    }
}
