//
//  ItemStockFormSheet.swift
//  RxStorage
//
//  Edit a stock placement's location, note, images, and positions
//

import OpenAPIRuntime
import PhotosUI
import RxStorageCore
import SwiftUI

struct ItemStockFormSheet: View {
    let onSaved: () -> Void

    @State private var viewModel: ItemStockFormViewModel
    @State private var errorViewModel = ErrorViewModel()
    @State private var showingLocationPicker = false
    @State private var showingPositionSheet = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    init(stock: ItemStock, onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: ItemStockFormViewModel(stock: stock))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Parent", value: viewModel.stock.parent?.value1.title ?? "No parent")
                LabeledContent("Quantity", value: "\(viewModel.stock.quantity)")
            } footer: {
                Text("Use Move to change the parent or quantity of this placement.")
            }

            locationSection

            Section("Note") {
                TextField("Note (optional)", text: $viewModel.note, axis: .vertical)
                    .accessibilityIdentifier("stock-form-note")
            }

            imagesSection
            positionsSection
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Placement")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(viewModel.isSubmitting || viewModel.isUploading)
                    .accessibilityIdentifier("stock-form-save-button")
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                NavigationStack {
                    LocationPickerSheet(selectedId: viewModel.selectedLocationId) { location in
                        viewModel.selectedLocationId = location?.id
                        viewModel.selectedLocationTitle = location?.title
                    }
                }
            }
            .sheet(isPresented: $showingPositionSheet) {
                NavigationStack {
                    PositionFormSheet(
                        positionSchemas: $viewModel.positionSchemas,
                        onSubmit: { schema, data in
                            viewModel.addPendingPosition(schema: schema, data: data)
                        }
                    )
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, newValue in
                Task { await handleSelectedPhotos(newValue) }
            }
        #if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPickerView { image in
                    Task { await handleCapturedImage(image) }
                }
                .ignoresSafeArea()
            }
        #endif
            .interactiveDismissDisabled(true)
            .overlay {
                if viewModel.isSubmitting || viewModel.isUploading {
                    LoadingOverlay()
                }
            }
            .task {
                await viewModel.loadReferenceData()
            }
            .showViewModelError(errorViewModel)
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section("Location") {
            Button {
                showingLocationPicker = true
            } label: {
                HStack {
                    Text("Location")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(viewModel.selectedLocationTitle ?? "None")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("stock-form-location-picker")

            if viewModel.selectedLocationId != nil {
                Button("Clear Location", role: .destructive) {
                    viewModel.selectedLocationId = nil
                    viewModel.selectedLocationTitle = nil
                }
            }
        }
    }

    private var imagesSection: some View {
        Section("Images") {
            ForEach(Array(viewModel.existingImages.enumerated()), id: \.element.id) { index, imageRef in
                HStack {
                    CachedAsyncImage(url: URL(string: imageRef.url)) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Image \(index + 1)")
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removeSavedImage(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            ForEach(viewModel.pendingUploads) { pending in
                HStack {
                    Text(pending.filename)
                        .lineLimit(1)
                    Spacer()
                    if pending.status.isInProgress {
                        ProgressView(value: pending.progress)
                            .frame(width: 80)
                    } else if pending.status.isFailed {
                        Text("Failed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if pending.status.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if !pending.status.isCompleted {
                        Button(role: .destructive) {
                            viewModel.removePendingUpload(id: pending.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
            }

            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                #if os(iOS)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                #endif
            } label: {
                Label("Add Images", systemImage: "photo.badge.plus")
            }
            .disabled(viewModel.isUploading)
        }
    }

    private var positionsSection: some View {
        Section("Positions") {
            ForEach(viewModel.positions) { position in
                positionRow(
                    name: viewModel.schemaName(for: position.positionSchemaId),
                    summary: summary(position.data.additionalProperties.mapValues { $0.value as Any? })
                ) {
                    viewModel.removePosition(id: position.id)
                }
            }

            ForEach(viewModel.pendingPositions) { pending in
                positionRow(
                    name: pending.schema.name,
                    summary: summary(pending.data.mapValues { $0.value as Any? })
                ) {
                    viewModel.removePendingPosition(id: pending.id)
                }
            }

            Button {
                showingPositionSheet = true
            } label: {
                Label("Add Position", systemImage: "plus.circle")
            }
        }
    }

    private func positionRow(name: String, summary: String, onRemove: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
        }
    }

    private func summary(_ data: [String: Any?]) -> String {
        data.sorted { $0.key < $1.key }.map { key, value in
            switch value {
            case let bool as Bool:
                return "\(key): \(bool ? "Yes" : "No")"
            case let .some(value):
                return "\(key): \(value)"
            case .none:
                return "\(key): -"
            }
        }
        .joined(separator: ", ")
    }

    // MARK: - Actions

    private func save() async {
        do {
            try await viewModel.submit()
            onSaved()
            dismiss()
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            if (try? data.write(to: tempURL)) != nil {
                viewModel.addImage(from: tempURL)
            }
        }
        selectedPhotos = []
        await viewModel.uploadPendingImages()
    }

    #if os(iOS)
        private func handleCapturedImage(_ image: UIImage) async {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            guard (try? data.write(to: tempURL)) != nil else { return }
            viewModel.addImage(from: tempURL)
            await viewModel.uploadPendingImages()
        }
    #endif
}
