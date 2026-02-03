//
//  QRCodeView.swift
//  RxStorage
//
//  Simple QR code view that displays a QR code from a string
//

import CoreImage.CIFilterBuiltins
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Simple QR code view that displays a QR code from a URL string
struct QRCodeView: View {
    let urlString: String

    #if os(iOS)
    @State private var qrImage: UIImage?
    #elseif os(macOS)
    @State private var qrImage: NSImage?
    #endif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if let image = qrImage {
                #if os(iOS)
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding()
                    .background(Color.primary)
                    .cornerRadius(12)
                #elseif os(macOS)
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding()
                    .background(Color.primary)
                    .cornerRadius(12)
                #endif

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }

            #if os(iOS)
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
            #elseif os(macOS)
            if let image = qrImage {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(nsImage: image), preview: SharePreview("QR Code", image: Image(nsImage: image))) {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                    }
                }
            }
            #endif
        }
        .task {
            qrImage = generateQRCode(from: urlString)
        }
    }

    // MARK: - QR Code Generation

    #if os(iOS)
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
    #elseif os(macOS)
    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        return nil
    }
    #endif
}

#Preview {
    NavigationStack {
        QRCodeView(urlString: "https://example.com/preview/1")
    }
}
