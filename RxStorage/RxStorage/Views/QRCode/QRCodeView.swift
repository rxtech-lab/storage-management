//
//  QRCodeView.swift
//  RxStorage
//
//  Simple QR code view that displays a QR code from a string
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Simple QR code view that displays a QR code from a URL string
struct QRCodeView: View {
    let urlString: String

    @State private var qrImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding()
                    .background(Color.primary)
                    .cornerRadius(12)

                Text(urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

            } else {
                ProgressView("Generating QR Code...")
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

            if let image = qrImage {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        printQRCode(image)
                    } label: {
                        Label("Print QR Code", systemImage: "printer")
                            .frame(maxWidth: .infinity)
                    }
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("QR Code", image: Image(uiImage: image))) {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        saveToPhotos(image)
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .task {
            qrImage = generateQRCode(from: urlString)
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
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
        QRCodeView(urlString: "https://example.com/preview/1")
    }
}
