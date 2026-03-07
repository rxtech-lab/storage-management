//
//  TagFormSheet.swift
//  RxStorage
//
//  Form sheet for creating new tags
//

import RxStorageCore
import SwiftUI

/// Form sheet for creating a new tag with title and color picker
struct TagFormSheet: View {
    let initialTitle: String
    let onCreated: (Tag) -> Void

    @State private var title: String
    @State private var color: Color = .blue
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let tagService = TagService()

    init(initialTitle: String = "", onCreated: @escaping (Tag) -> Void) {
        self.initialTitle = initialTitle
        self.onCreated = onCreated
        _title = State(initialValue: initialTitle)
    }

    var body: some View {
        Form {
            Section {
                TextField("Tag Name", text: $title)

                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }

            Section("Preview") {
                HStack {
                    Spacer()
                    Text(title.isEmpty ? "Tag" : title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(isLightColor(color) ? .black : .white)
                        .background(color)
                        .clipShape(Capsule())
                    Spacer()
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("New Tag")
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
                    Button("Create") {
                        Task { await createTag() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
    }

    private func createTag() async {
        isSaving = true
        errorMessage = nil

        let hexColor = color.toHex()
        let request = NewTagRequest(title: title.trimmingCharacters(in: .whitespaces), color: hexColor)

        do {
            let tag = try await tagService.createTag(request)
            onCreated(tag)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func isLightColor(_ color: Color) -> Bool {
        #if os(iOS)
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        #else
            let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        #endif
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.5
    }
}

// MARK: - Color to Hex Extension

private extension Color {
    func toHex() -> String {
        #if os(iOS)
            let uiColor = UIColor(self)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        #else
            let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        #endif
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
