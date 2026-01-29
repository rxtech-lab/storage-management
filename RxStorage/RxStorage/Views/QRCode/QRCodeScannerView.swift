//
//  QRCodeScannerView.swift
//  RxStorage
//
//  QR code scanner view using AVFoundation
//

import SwiftUI
import AVFoundation

/// QR code scanner view
struct QRCodeScannerView: View {
    let onScan: (String) -> Void

    @State private var isScanningEnabled = true
    @Environment(\.dismiss) private var dismiss

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(isScanningEnabled: $isScanningEnabled, onScan: { code in
                onScan(code)
                dismiss()
            })
            .edgesIgnoringSafeArea(.all)

            // Overlay with instructions
            VStack {
                Spacer()

                Text("Position the QR code within the frame")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding()
            }
        }
        .navigationTitle("Scan QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
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

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard isScanningEnabled else { return }

            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let stringValue = metadataObject.stringValue {
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
