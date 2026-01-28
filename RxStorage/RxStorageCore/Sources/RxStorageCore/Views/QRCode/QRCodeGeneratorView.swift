//
//  QRCodeGeneratorView.swift
//  RxStorageCore
//
//  QR code generator view with save/share/print functionality
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// QR code generator view
public struct QRCodeGeneratorView: View {
    let itemId: Int

    @State private var viewModel = ItemDetailViewModel()
    @State private var qrImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    public init(itemId: Int) {
        self.itemId = itemId
    }

    public var body: some View {
        VStack(spacing: 20) {
            if viewModel.isGeneratingQR {
                ProgressView("Generating QR Code...")
            } else if let qrCodeData = viewModel.qrCodeData {
                VStack(spacing: 20) {
                    // QR Code Image
                    if let image = generateQRCode(from: qrCodeData.previewUrl) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .onAppear {
                                qrImage = image
                            }
                    }

                    // URL
                    Text(qrCodeData.previewUrl)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        if let image = qrImage {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview("QR Code", image: Image(uiImage: image))) {
                                Label("Share QR Code", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                printQRCode(image)
                            } label: {
                                Label("Print QR Code", systemImage: "printer")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                saveToPhotos(image)
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Failed to Generate QR Code",
                    systemImage: "qrcode.viewfinder",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .navigationTitle("QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.generateQRCode()
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            // Scale up the QR code
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return nil
    }

    // MARK: - Actions

    private func printQRCode(_ image: UIImage) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "QR Code"

        printController.printInfo = printInfo
        printController.printingItem = image

        printController.present(animated: true)
    }

    private func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

#Preview {
    NavigationStack {
        QRCodeGeneratorView(itemId: 1)
    }
}
