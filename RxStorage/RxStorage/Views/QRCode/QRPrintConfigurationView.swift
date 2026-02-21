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
            if case let .custom(w, h) = saved.pageSize {
                _customWidth = State(initialValue: "\(Int(w))")
                _customHeight = State(initialValue: "\(Int(h))")
                _isCustomSize = State(initialValue: true)
            } else {
                _customWidth = State(initialValue: "612")
                _customHeight = State(initialValue: "792")
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
                    NavigationLink {
                        CustomPageSizeView(
                            width: $customWidth,
                            height: $customHeight,
                            onChanged: { updateCustomSize() }
                        )
                    } label: {
                        HStack {
                            Text("Custom Size")
                            Spacer()
                            Text("\(customWidth) × \(customHeight) pt")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
            let w = CGFloat(Double(customWidth) ?? 612)
            let h = CGFloat(Double(customHeight) ?? 792)
            configuration.pageSize = .custom(width: max(w, 72), height: max(h, 72))
        }

        // MARK: - Print Action

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

            printController.present(animated: true)
        }
    }

    // MARK: - Custom Page Size View

    private struct CustomPageSizeView: View {
        @Binding var width: String
        @Binding var height: String
        let onChanged: () -> Void

        var body: some View {
            Form {
                Section {
                    HStack {
                        Text("Width (pt)")
                        Spacer()
                        TextField("Width", text: $width)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: width) { onChanged() }
                    }
                    HStack {
                        Text("Height (pt)")
                        Spacer()
                        TextField("Height", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: height) { onChanged() }
                    }
                }

                Section("Common Sizes") {
                    ForEach(PrintPageSize.allPresets) { size in
                        Button {
                            width = "\(Int(size.width))"
                            height = "\(Int(size.height))"
                        } label: {
                            HStack {
                                Text(size.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(size.width)) × \(Int(size.height)) pt")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
            positions: []
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

        return QRPrintConfigurationView(item: item, qrImage: qrImage)
    }

#endif
