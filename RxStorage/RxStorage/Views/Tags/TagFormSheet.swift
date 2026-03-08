//
//  TagFormSheet.swift
//  RxStorage
//
//  Form sheet for creating and editing tags
//

import RxStorageCore
import SwiftUI

/// Form sheet for creating or editing a tag with title and color picker
struct TagFormSheet: View {
    let editingTag: Tag?
    let onCreated: ((Tag) -> Void)?
    let onUpdated: ((Tag) -> Void)?

    @State private var title: String
    @State private var color: Color
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let tagService = TagService()

    private var isEditing: Bool {
        editingTag != nil
    }

    /// Create mode initializer
    init(initialTitle: String = "", onCreated: @escaping (Tag) -> Void) {
        editingTag = nil
        self.onCreated = onCreated
        onUpdated = nil
        _title = State(initialValue: initialTitle)
        _color = State(initialValue: .blue)
    }

    /// Edit mode initializer
    init(tag: Tag, onUpdated: @escaping (Tag) -> Void) {
        editingTag = tag
        onCreated = nil
        self.onUpdated = onUpdated
        _title = State(initialValue: tag.title)
        _color = State(initialValue: Color(hex: tag.color) ?? .blue)
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
        .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
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
                    Button(isEditing ? "Save" : "Create") {
                        Task { await saveTag() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
    }

    private func saveTag() async {
        isSaving = true
        errorMessage = nil

        let hexColor = color.toHex()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        do {
            if let editingTag {
                let request = UpdateTagRequest(title: trimmedTitle, color: hexColor)
                let updated = try await tagService.updateTag(id: editingTag.id, request)
                onUpdated?(updated)
            } else {
                let request = NewTagRequest(title: trimmedTitle, color: hexColor)
                let created = try await tagService.createTag(request)
                onCreated?(created)
            }
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

// MARK: - Color Extensions

private extension Color {
    init?(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else { return nil }
        self.init(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }

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
