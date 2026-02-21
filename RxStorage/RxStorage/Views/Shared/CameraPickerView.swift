//
//  CameraPickerView.swift
//  RxStorage
//
//  UIImagePickerController wrapper for taking photos with the camera
//

#if os(iOS)
    import SwiftUI
    import UIKit

    struct CameraPickerView: UIViewControllerRepresentable {
        @Environment(\.dismiss) private var dismiss
        var onImageCaptured: (UIImage) -> Void

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_: UIImagePickerController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(dismiss: dismiss, onImageCaptured: onImageCaptured)
        }

        class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let dismiss: DismissAction
            let onImageCaptured: (UIImage) -> Void

            init(dismiss: DismissAction, onImageCaptured: @escaping (UIImage) -> Void) {
                self.dismiss = dismiss
                self.onImageCaptured = onImageCaptured
            }

            func imagePickerController(
                _: UIImagePickerController,
                didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
            ) {
                if let image = info[.originalImage] as? UIImage {
                    onImageCaptured(image)
                }
                dismiss()
            }

            func imagePickerControllerDidCancel(_: UIImagePickerController) {
                dismiss()
            }
        }
    }
#endif
