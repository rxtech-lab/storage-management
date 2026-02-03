//
//  QRCodeScannerView.swift
//  RxStorage
//
//  QR code scanner view using AVFoundation and Vision
//

import AVFoundation
import PhotosUI
import SwiftUI
#if os(iOS)
import UIKit
import Vision

/// Scan mode for QR code scanner
enum ScanMode {
    case camera
    case photoLibrary
}

/// Errors specific to QR code scanning from images
private enum QRCodeError: LocalizedError {
    case invalidImage
    case noQRCodeFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the selected image"
        case .noQRCodeFound:
            return "No QR code found in the image"
        }
    }
}

/// QR code scanner view
struct QRCodeScannerView: View {
    let onScan: (String) -> Void

    @State private var isScanningEnabled = true
    @State private var scanMode: ScanMode = .camera
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessingImage = false
    @State private var imageError: String?
    @Environment(\.dismiss) private var dismiss

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    var body: some View {
        ZStack {
            // Content based on scan mode
            switch scanMode {
            case .camera:
                // Camera preview
                CameraPreview(isScanningEnabled: $isScanningEnabled, onScan: { code in
                    onScan(code)
                    dismiss()
                })
                .edgesIgnoringSafeArea(.all)

            case .photoLibrary:
                // Photo library mode content
                photoLibraryContent
            }

            // Overlay with instructions and mode toggle
            VStack {
                Text(
                    scanMode == .camera
                        ? "Position the QR code within the frame"
                        : "Select an image containing a QR code"
                )
                .padding()
                .glassEffect()

                Spacer()

                // Mode toggle toolbar
                modeToggleToolbar
                    .padding(.bottom)
            }
        }
        .navigationTitle("Scan QR Code")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await handleSelectedPhoto(newValue)
            }
        }
        .alert("Error", isPresented: .constant(imageError != nil)) {
            Button("OK") {
                imageError = nil
            }
        } message: {
            if let error = imageError {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private var photoLibraryContent: some View {
        VStack {
            if isProcessingImage {
                ProgressView("Detecting QR code...")
            } else if let image = selectedImage {
                // Show selected image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            } else {
                // Placeholder when no image selected
                ContentUnavailableView {
                    Label("No Image Selected", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Tap the photo button below to select an image")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var modeToggleToolbar: some View {
        HStack(spacing: 20) {
            // Camera mode button
            Button {
                scanMode = .camera
                selectedImage = nil
                selectedPhotoItem = nil
                isScanningEnabled = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(scanMode == .camera ? .primary : .secondary)
            }
            .padding()
            .background(scanMode == .camera ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(Capsule())

            // Photo picker button
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Label("Photos", systemImage: "photo.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .padding()
            .background(scanMode == .photoLibrary ? Color.accentColor.opacity(0.5) : Color.clear)
            .clipShape(Capsule())
            .onChange(of: selectedPhotoItem) { _, _ in
                // Switch to photo mode when photo is selected
                if scanMode == .camera {
                    scanMode = .photoLibrary
                    isScanningEnabled = false
                }
            }
        }
        .glassEffect()
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        await MainActor.run {
            isProcessingImage = true
            imageError = nil
        }

        do {
            // Load image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else {
                await MainActor.run {
                    imageError = "Failed to load the selected image"
                    isProcessingImage = false
                }
                return
            }

            // Update UI with selected image
            await MainActor.run {
                selectedImage = uiImage
            }

            // Detect QR code
            let code = try await detectQRCode(from: uiImage)

            // Success - call the onScan callback
            await MainActor.run {
                isProcessingImage = false
                onScan(code)
                dismiss()
            }

        } catch let error as QRCodeError {
            await MainActor.run {
                imageError = error.localizedDescription
                isProcessingImage = false
            }
        } catch {
            await MainActor.run {
                imageError = "Failed to process image: \(error.localizedDescription)"
                isProcessingImage = false
            }
        }
    }

    /// Detect QR codes from a UIImage using Vision framework with CIDetector fallback
    private func detectQRCode(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw QRCodeError.invalidImage
        }

        // Try Vision framework first
        do {
            return try await detectQRCodeWithVision(cgImage: cgImage)
        } catch {
            // Fall back to CIDetector (works better in simulator)
            return try detectQRCodeWithCIDetector(cgImage: cgImage)
        }
    }

    /// Vision framework-based QR detection (preferred on real devices)
    private func detectQRCodeWithVision(cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let request = VNDetectBarcodesRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNBarcodeObservation],
                      let firstBarcode = results.first(where: { $0.symbology == .qr }),
                      let payload = firstBarcode.payloadStringValue
                else {
                    continuation.resume(throwing: QRCodeError.noQRCodeFound)
                    return
                }

                continuation.resume(returning: payload)
            }

            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: error)
            }
        }
    }

    /// CIDetector-based QR detection (fallback for simulator)
    private func detectQRCodeWithCIDetector(cgImage: CGImage) throws -> String {
        let ciImage = CIImage(cgImage: cgImage)

        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ) else {
            throw QRCodeError.noQRCodeFound
        }

        let features = detector.features(in: ciImage)

        guard let qrFeature = features.first as? CIQRCodeFeature,
              let payload = qrFeature.messageString
        else {
            throw QRCodeError.noQRCodeFound
        }

        return payload
    }
}

/// Camera preview view using AVFoundation
struct CameraPreview: UIViewRepresentable {
    @Binding var isScanningEnabled: Bool
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let captureSession = AVCaptureSession()
        context.coordinator.captureSession = captureSession

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return view
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return view
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return view
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return view
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isScanningEnabled: $isScanningEnabled, onScan: onScan)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        @Binding var isScanningEnabled: Bool
        let onScan: (String) -> Void
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?

        init(isScanningEnabled: Binding<Bool>, onScan: @escaping (String) -> Void) {
            self._isScanningEnabled = isScanningEnabled
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard isScanningEnabled else { return }

            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let stringValue = metadataObject.stringValue
            {
                isScanningEnabled = false
                captureSession?.stopRunning()
                onScan(stringValue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        QRCodeScannerView { code in
            print("Scanned: \(code)")
        }
    }
}
#endif
