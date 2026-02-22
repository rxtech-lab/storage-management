//
//  QRPrintConfigurationView.swift
//  RxStorage
//
//  Configuration sheet for QR code print settings with live preview
//

import RxStorageCore
import SwiftUI

#if os(iOS)

    /// Configuration sheet that allows users to customize QR code print layout
    struct QRPrintConfigurationView: View {
        let item: StorageItemDetail
        let qrImage: UIImage

        @State private var configuration = QRPrintConfiguration.loadSaved()
        @State private var customWidth: String
        @State private var customHeight: String
        @State private var isCustomSize: Bool
        @Environment(\.dismiss) private var dismiss

        init(item: StorageItemDetail, qrImage: UIImage) {
            self.item = item
            self.qrImage = qrImage
            let saved = QRPrintConfiguration.loadSaved()
            let unit = saved.sizeUnit
            if case let .custom(w, h) = saved.pageSize {
                let displayW = unit.fromPoints(w)
                let displayH = unit.fromPoints(h)
                _customWidth = State(initialValue: "\(Int(displayW.rounded()))")
                _customHeight = State(initialValue: "\(Int(displayH.rounded()))")
                _isCustomSize = State(initialValue: true)
            } else {
                let defaultW = unit.fromPoints(612)
                let defaultH = unit.fromPoints(792)
                _customWidth = State(initialValue: "\(Int(defaultW.rounded()))")
                _customHeight = State(initialValue: "\(Int(defaultH.rounded()))")
                _isCustomSize = State(initialValue: false)
            }
            _configuration = State(initialValue: saved)
        }

        var body: some View {
            NavigationStack {
                List {
                    previewSection
                    pageSizeSection
                    layoutSection
                    fieldsSection
                }
                .navigationTitle("Print Settings")
                .navigationBarTitleDisplayMode(.inline)
                .onDisappear { configuration.save() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            printQRCode()
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                    }
                }
            }
        }

        // MARK: - Preview Section

        private var previewSection: some View {
            Section("Preview") {
                GeometryReader { geometry in
                    let scale = geometry.size.width / configuration.pageSize.width
                    QRPrintLayoutView(
                        item: item,
                        qrImage: qrImage,
                        configuration: configuration
                    )
                    .scaleEffect(scale, anchor: .topLeading)
                }
                .aspectRatio(
                    configuration.pageSize.width / configuration.pageSize.height,
                    contentMode: .fit
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }

        // MARK: - Fields Section

        private var fieldsSection: some View {
            Section("Fields") {
                ForEach(configuration.fieldOrder) { field in
                    HStack {
                        Image(systemName: field.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(field.displayName)

                        Spacer()

                        if configuration.fieldValue(for: field, item: item) == nil {
                            Text("N/A")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Toggle("", isOn: fieldBinding(for: field))
                            .labelsHidden()
                    }
                }
                .onMove { source, destination in
                    configuration.moveFields(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))
        }

        private func fieldBinding(for field: QRPrintField) -> Binding<Bool> {
            Binding(
                get: { configuration.enabledFields.contains(field) },
                set: { _ in configuration.toggleField(field) }
            )
        }

        // MARK: - Layout Section

        private var layoutSection: some View {
            Section("Layout") {
                Picker("QR Code Position", selection: $configuration.qrCodePosition) {
                    ForEach(QRCodePosition.allCases) { position in
                        Label(position.displayName, systemImage: position.icon).tag(position)
                    }
                }

                Picker("Horizontal Alignment", selection: $configuration.alignment) {
                    ForEach(PrintAlignment.allCases) { alignment in
                        Label(alignment.displayName, systemImage: alignment.icon).tag(alignment)
                    }
                }

                Picker("Vertical Alignment", selection: $configuration.verticalAlignment) {
                    ForEach(PrintVerticalAlignment.allCases) { alignment in
                        Label(alignment.displayName, systemImage: alignment.icon).tag(alignment)
                    }
                }

                HStack {
                    Text("QR Size")
                    Slider(
                        value: $configuration.qrCodeSize,
                        in: 40 ... min(min(configuration.pageSize.width, configuration.pageSize.height) * 0.8, 400),
                        step: 4
                    )
                    Text("\(Int(configuration.qrCodeSize)) pt")
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("Font Size")
                    Slider(
                        value: $configuration.fontSize,
                        in: 8 ... 36,
                        step: 1
                    )
                    Text("\(Int(configuration.fontSize)) pt")
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("Padding")
                    Slider(
                        value: $configuration.padding,
                        in: 0 ... 100,
                        step: 4
                    )
                    Text("\(Int(configuration.padding)) pt")
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("V Spacing")
                    Slider(
                        value: $configuration.verticalSpacing,
                        in: 0 ... 80,
                        step: 4
                    )
                    Text("\(Int(configuration.verticalSpacing)) pt")
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                if configuration.qrCodePosition.isHorizontal {
                    HStack {
                        Text("H Spacing")
                        Slider(
                            value: $configuration.horizontalSpacing,
                            in: 0 ... 80,
                            step: 4
                        )
                        Text("\(Int(configuration.horizontalSpacing)) pt")
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }

        // MARK: - Page Size Section

        private var pageSizeSection: some View {
            Section("Paper Size") {
                Picker("Paper Size", selection: pageSizeBinding) {
                    ForEach(PrintPageSize.allPresets) { size in
                        Text(size.displayName).tag(size)
                    }
                    Text("Custom").tag(
                        PrintPageSize.custom(
                            width: CGFloat(Double(customWidth) ?? 612),
                            height: CGFloat(Double(customHeight) ?? 792)
                        )
                    )
                }

                if isCustomSize {
                    Picker("Unit", selection: sizeUnitBinding) {
                        ForEach(PrintSizeUnit.allCases) { unit in
                            Text(unit.abbreviation).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        CustomPageSizeView(
                            width: $customWidth,
                            height: $customHeight,
                            sizeUnit: configuration.sizeUnit,
                            onChanged: { updateCustomSize() }
                        )
                    } label: {
                        HStack {
                            Text("Custom Size")
                            Spacer()
                            Text("\(customWidth) × \(customHeight) \(configuration.sizeUnit.abbreviation)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        private var sizeUnitBinding: Binding<PrintSizeUnit> {
            Binding(
                get: { configuration.sizeUnit },
                set: { newUnit in
                    let oldUnit = configuration.sizeUnit
                    guard newUnit != oldUnit else { return }
                    // Convert current text field values to the new unit
                    if let wPts = Double(customWidth).map({ oldUnit.toPoints(CGFloat($0)) }),
                       let hPts = Double(customHeight).map({ oldUnit.toPoints(CGFloat($0)) })
                    {
                        let newW = newUnit.fromPoints(wPts)
                        let newH = newUnit.fromPoints(hPts)
                        customWidth = "\(Int(newW.rounded()))"
                        customHeight = "\(Int(newH.rounded()))"
                    }
                    configuration.sizeUnit = newUnit
                }
            )
        }

        private var pageSizeBinding: Binding<PrintPageSize> {
            Binding(
                get: { configuration.pageSize },
                set: { newValue in
                    if case .custom = newValue {
                        isCustomSize = true
                        updateCustomSize()
                    } else {
                        isCustomSize = false
                        configuration.pageSize = newValue
                    }
                }
            )
        }

        private func updateCustomSize() {
            let unit = configuration.sizeUnit
            let w = unit.toPoints(CGFloat(Double(customWidth) ?? unit.fromPoints(612)))
            let h = unit.toPoints(CGFloat(Double(customHeight) ?? unit.fromPoints(792)))
            configuration.pageSize = .custom(width: max(w, 72), height: max(h, 72))
        }

        // MARK: - Print Action

        /// Delegate retained during print interaction to auto-select paper size
        @State private var printDelegate: PrintPaperDelegate?

        private func printQRCode() {
            let layoutView = QRPrintLayoutView(
                item: item,
                qrImage: qrImage,
                configuration: configuration
            )

            let renderer = ImageRenderer(content: layoutView)
            renderer.scale = 3.0

            guard let printImage = renderer.uiImage else { return }

            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo.printInfo()
            printInfo.outputType = .general
            printInfo.jobName = "QR Code - \(item.title)"

            printController.printInfo = printInfo
            printController.printingItem = printImage

            let delegate = PrintPaperDelegate(
                pageSize: CGSize(
                    width: configuration.pageSize.width,
                    height: configuration.pageSize.height
                )
            )
            printDelegate = delegate
            printController.delegate = delegate

            printController.present(animated: true)
        }
    }

    // MARK: - Print Paper Delegate

    /// Delegate that auto-selects the best matching paper size for the print dialog
    private final class PrintPaperDelegate: NSObject, UIPrintInteractionControllerDelegate {
        let pageSize: CGSize

        init(pageSize: CGSize) {
            self.pageSize = pageSize
        }

        func printInteractionController(
            _: UIPrintInteractionController,
            choosePaper paperList: [UIPrintPaper]
        ) -> UIPrintPaper {
            UIPrintPaper.bestPaper(forPageSize: pageSize, withPapersFrom: paperList)
        }
    }

    // MARK: - Custom Page Size View

    private struct CustomPageSizeView: View {
        @Binding var width: String
        @Binding var height: String
        let sizeUnit: PrintSizeUnit
        let onChanged: () -> Void
        @FocusState private var isInputActive: Bool

        var body: some View {
            Form {
                Section {
                    HStack {
                        Text("Width (\(sizeUnit.abbreviation))")
                        Spacer()
                        TextField("Width", text: $width)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .focused($isInputActive)
                            .onChange(of: width) { onChanged() }
                    }
                    HStack {
                        Text("Height (\(sizeUnit.abbreviation))")
                        Spacer()
                        TextField("Height", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .focused($isInputActive)
                            .onChange(of: height) { onChanged() }
                    }
                }

                Section("Common Sizes") {
                    ForEach(PrintPageSize.allPresets) { size in
                        let displayW = Int(sizeUnit.fromPoints(size.width).rounded())
                        let displayH = Int(sizeUnit.fromPoints(size.height).rounded())
                        Button {
                            width = "\(displayW)"
                            height = "\(displayH)"
                        } label: {
                            HStack {
                                Text(size.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(displayW) × \(displayH) \(sizeUnit.abbreviation)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isInputActive = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputActive = false }
                }
            }
            .navigationTitle("Custom Size")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Preview

    #Preview("Print Configuration") {
        let item = StorageItemDetail(
            id: 1,
            userId: "preview",
            title: "Sample Item",
            description: "A sample item for preview",
            originalQrCode: nil,
            categoryId: 1,
            locationId: 1,
            authorId: 1,
            parentId: nil,
            price: 29.99,
            currency: "USD",
            visibility: .publicAccess,
            createdAt: Date(),
            updatedAt: Date(),
            previewUrl: "https://example.com/preview/1",
            images: [],
            category: StorageItemDetail.categoryPayload(
                value1: CategoryRef(id: 1, name: "Electronics")
            ),
            location: StorageItemDetail.locationPayload(
                value1: LocationRef(id: 1, title: "Office", latitude: 0, longitude: 0)
            ),
            author: nil,
            children: [],
            contents: [],
            positions: [],
            quantity: 0,
            stockHistory: []
        )

        // Generate a simple QR code image for preview
        let qrImage: UIImage = {
            let data = "https://example.com/preview/1".data(using: .utf8)!
            let filter = CIFilter(name: "CIQRCodeGenerator")!
            filter.setValue(data, forKey: "inputMessage")
            let ciImage = filter.outputImage!
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaled = ciImage.transformed(by: transform)
            return UIImage(ciImage: scaled)
        }()

        QRPrintConfigurationView(item: item, qrImage: qrImage)
    }

#endif
