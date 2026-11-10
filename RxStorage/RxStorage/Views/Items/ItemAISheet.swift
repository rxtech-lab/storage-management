import ImageIO
import PhotosUI
import RxStorageCore
import SwiftUI
import UniformTypeIdentifiers

/// AI drafting and relation creation have a dedicated review sheet.
struct ItemAISheet: View {
    let context: ItemAIRequest
    let onApply: (ItemAIResponse, ItemAIRelations, [ImageReference], [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var webSearch = true
    @State private var photos: [PhotosPickerItem] = []
    @State private var attachments: [ImageReference] = []
    @State private var result: ItemAIResponse?
    @State private var useCategory = false
    @State private var useAuthor = false
    @State private var selectedTags: Set<String> = []
    @State private var busy = false
    @State private var error: String?
    @State private var feedback = 0

    var body: some View {
        Form {
            if result != nil {
                reviewSections
            } else {
                Section("Item details") {
                    TextField("Describe the item, model, or ISBN", text: $prompt, axis: .vertical)
                        .lineLimit(5 ... 10)
                        .accessibilityIdentifier("item-ai-prompt")
                    PhotosPicker(selection: $photos, maxSelectionCount: max(0, 5 - context.images.count - attachments.count), matching: .images) {
                        Label("Attach images", systemImage: "photo.badge.plus")
                    }
                    .disabled(context.images.count + attachments.count >= 5)
                    .accessibilityIdentifier("item-ai-attach-images")
                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, _ in
                        Button("Remove attached image \(index + 1)", role: .destructive) {
                            attachments.remove(at: index)
                            feedback += 1
                        }
                    }
                    if !context.images.isEmpty {
                        Text("\(context.images.count) form images included")
                    }
                }
                Section {
                    Toggle("Search the web for item information", isOn: $webSearch)
                        .accessibilityIdentifier("item-ai-web-search")
                    Button("Generate draft") { Task { await generate() } }
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && context.title.isEmpty && context.originalQrCode.isEmpty && context.images.isEmpty && attachments.isEmpty)
                        .accessibilityIdentifier("item-ai-generate")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(result == nil ? "Create using AI" : "Review AI draft")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: feedback)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(busy)
                        .accessibilityIdentifier("item-ai-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if result != nil {
                        Button("Apply draft") { Task { await apply() } }
                            .disabled(busy || result?.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true)
                            .accessibilityIdentifier("item-ai-apply")
                    }
                }
            }
            .disabled(busy)
            .interactiveDismissDisabled(busy)
            .overlay { if busy { LoadingOverlay() } }
            .alert("AI item", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .onChange(of: photos) { _, selection in Task { await upload(selection) } }
    }

    private var reviewSections: some View {
        Group {
            Section("Draft") {
                TextField("Title", text: Binding(get: { result?.draft.title ?? "" }, set: { result?.draft.title = $0 }))
                TextField("Description", text: Binding(get: { result?.draft.description ?? "" }, set: { result?.draft.description = $0 }), axis: .vertical)
                    .lineLimit(3 ... 10)
                if let code = result?.draft.originalQrCode { LabeledContent("QR code", value: code) }
            }
            Section("Create or reuse suggestions") {
                if let category = result?.draft.category { Toggle("Category: \(category)", isOn: $useCategory) }
                if let author = result?.draft.author { Toggle("Author: \(author)", isOn: $useAuthor) }
                ForEach(result?.draft.tags ?? [], id: \.self) { tag in
                    Toggle("Tag: \(tag)", isOn: Binding(get: { selectedTags.contains(tag) }, set: { if $0 { selectedTags.insert(tag) } else { selectedTags.remove(tag) } }))
                }
            }
            if let sources = result?.sources, !sources.isEmpty {
                Section("Sources") {
                    ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                        if let url = URL(string: source.url), ["https", "http"].contains(url.scheme ?? "") { Link(source.title, destination: url) }
                    }
                }
            }
            Section {
                Button("Back to prompt") { result = nil; feedback += 1 }
                Text("Applying creates selected related records. Review the item form before saving the item.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func generate() async {
        busy = true
        defer { busy = false; feedback += 1 }
        var request = context
        request.prompt = prompt
        request.webSearch = webSearch
        request.images += attachments.map(\.fileReference)
        do {
            result = try await ItemAIService().generate(request)
            useCategory = false
            useAuthor = false
            selectedTags = []
        } catch { self.error = error.localizedDescription }
    }

    private func apply() async {
        guard let result else { return }
        busy = true
        defer { busy = false; feedback += 1 }
        do {
            let relations = try await ItemAIService().createRelations(category: useCategory ? result.draft.category : nil, author: useAuthor ? result.draft.author : nil, tags: Array(selectedTags))
            onApply(result, relations, attachments, Array(selectedTags))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func upload(_ selected: [PhotosPickerItem]) async {
        guard !selected.isEmpty else { return }
        busy = true
        defer { busy = false; photos = []; feedback += 1 }
        do {
            for photo in selected {
                guard let data = try await photo.loadTransferable(type: Data.self) else { throw UploadError.invalidContentType }
                guard data.count <= 10 * 1024 * 1024 else { throw UploadError.fileTooLarge(maxSize: 10 * 1024 * 1024) }
                // Normalize HEIC and library assets to a model-supported image format.
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                          kCGImageSourceCreateThumbnailFromImageAlways: true,
                          kCGImageSourceThumbnailMaxPixelSize: 2048,
                          kCGImageSourceCreateThumbnailWithTransform: true,
                      ] as CFDictionary)
                else { throw UploadError.invalidContentType }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw UploadError.invalidFileURL }
                CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { throw UploadError.invalidContentType }
                defer { try? FileManager.default.removeItem(at: url) }
                let uploaded = try await UploadManager.shared.upload(file: url)
                attachments.append(ImageReference(url: uploaded.publicUrl, fileId: uploaded.fileId))
            }
        } catch { self.error = error.localizedDescription }
    }
}
