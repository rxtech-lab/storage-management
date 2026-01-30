//
//  ItemFormSheet.swift
//  RxStorage
//
//  Item create/edit form with inline entity creation
//

import PhotosUI
import RxStorageCore
import SwiftUI

/// Item form sheet for creating or editing items
struct ItemFormSheet: View {
    let item: StorageItem?

    @State private var viewModel: ItemFormViewModel
    @Environment(\.dismiss) private var dismiss

    // Inline creation sheets
    @State private var showingCategorySheet = false
    @State private var showingLocationSheet = false
    @State private var showingAuthorSheet = false
    @State private var showingPositionSheet = false

    // Photo picker
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(item: StorageItem? = nil) {
        self.item = item
        _viewModel = State(initialValue: ItemFormViewModel(item: item))
    }

    var body: some View {
        Form {
            // Basic Info
            Section("Basic Information") {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.words)

                TextField("Description", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3 ... 6)

                TextField("Price", text: $viewModel.price)
                    .keyboardType(.decimalPad)
            }

            // Category
            Section {
                Picker("Category", selection: $viewModel.selectedCategoryId) {
                    Text("None").tag(nil as Int?)
                    ForEach(viewModel.categories) { category in
                        Text(category.name).tag(category.id as Int?)
                    }
                }

                Button {
                    showingCategorySheet = true
                } label: {
                    Label("Create New Category", systemImage: "plus.circle")
                }
            } header: {
                Text("Category")
            }

            // Location
            Section {
                Picker("Location", selection: $viewModel.selectedLocationId) {
                    Text("None").tag(nil as Int?)
                    ForEach(viewModel.locations) { location in
                        Text(location.title).tag(location.id as Int?)
                    }
                }

                Button {
                    showingLocationSheet = true
                } label: {
                    Label("Create New Location", systemImage: "plus.circle")
                }
            } header: {
                Text("Location")
            }

            // Author
            Section {
                Picker("Author", selection: $viewModel.selectedAuthorId) {
                    Text("None").tag(nil as Int?)
                    ForEach(viewModel.authors) { author in
                        Text(author.name).tag(author.id as Int?)
                    }
                }

                Button {
                    showingAuthorSheet = true
                } label: {
                    Label("Create New Author", systemImage: "plus.circle")
                }
            } header: {
                Text("Author")
            }

            // Parent Item
            Section("Hierarchy") {
                Picker("Parent Item", selection: $viewModel.selectedParentId) {
                    Text("None").tag(nil as Int?)
                    ForEach(viewModel.parentItems) { parentItem in
                        Text(parentItem.title).tag(parentItem.id as Int?)
                    }
                }
            }

            // Visibility
            Section("Privacy") {
                Picker("Visibility", selection: $viewModel.visibility) {
                    Text("Public").tag(StorageItem.Visibility.public)
                    Text("Private").tag(StorageItem.Visibility.private)
                }
                .pickerStyle(.segmented)
            }

            // Images
            Section("Images") {
                // Saved images (from imageURLs)
                ForEach(Array(viewModel.imageURLs.enumerated()), id: \.offset) { index, url in
                    HStack {
                        AsyncImage(url: URL(string: url)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
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

                // Pending uploads with progress
                ForEach(viewModel.pendingUploads) { pending in
                    HStack {
                        // Local preview from file URL
                        if let image = loadImage(from: pending.localURL) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(pending.filename)
                                .lineLimit(1)
                                .font(.subheadline)

                            if pending.status.isInProgress {
                                ProgressView(value: pending.progress)
                                    .progressViewStyle(.linear)
                            } else if case .failed(let error) = pending.status {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            } else if pending.status.isCompleted {
                                Text("Uploaded")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }

                        Spacer()

                        if !pending.status.isCompleted {
                            Button(role: .destructive) {
                                viewModel.removePendingUpload(id: pending.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                        }
                    }
                }

                // PhotosPicker button
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Add Images", systemImage: "photo.badge.plus")
                }
                .disabled(viewModel.isUploading)
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await handleSelectedPhotos(newValue)
                }
            }

            // Positions
            Section {
                // Existing positions (edit mode)
                ForEach(viewModel.positions) { position in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(position.positionSchema?.name ?? "Position")
                                .font(.headline)
                            Text(positionDataSummary(position.data))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.removePosition(id: position.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                // Pending positions (new)
                ForEach(viewModel.pendingPositions) { pending in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pending.schema.name)
                                .font(.headline)
                            Text(positionDataSummary(pending.data))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.removePendingPosition(id: pending.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                }

                // Add position button
                Button {
                    showingPositionSheet = true
                } label: {
                    Label("Add Position", systemImage: "plus.circle")
                }
            } header: {
                Text("Positions")
            }

            // Validation Errors
            if !viewModel.validationErrors.isEmpty {
                Section {
                    ForEach(Array(viewModel.validationErrors.keys), id: \.self) { key in
                        if let error = viewModel.validationErrors[key] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle(item == nil ? "New Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(item == nil ? "Create" : "Save") {
                    Task {
                        await submitForm()
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .sheet(isPresented: $showingCategorySheet) {
            NavigationStack {
                CategoryFormSheet { newCategory in
                    viewModel.selectedCategoryId = newCategory.id
                }
            }
        }
        .sheet(isPresented: $showingLocationSheet) {
            NavigationStack {
                LocationFormSheet { newLocation in
                    viewModel.selectedLocationId = newLocation.id
                }
            }
        }
        .sheet(isPresented: $showingAuthorSheet) {
            NavigationStack {
                AuthorFormSheet { newAuthor in
                    viewModel.selectedAuthorId = newAuthor.id
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
        .task {
            await viewModel.loadReferenceData()
        }
        .overlay {
            if viewModel.isSubmitting || viewModel.isUploading {
                LoadingOverlay()
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        // Upload any remaining pending images first
        let pendingToUpload = viewModel.pendingUploads.filter { $0.status == .pending }
        if !pendingToUpload.isEmpty {
            await viewModel.uploadPendingImages()
        }

        // Check for failed uploads
        let failedUploads = viewModel.pendingUploads.filter { $0.status.isFailed }
        if !failedUploads.isEmpty {
            // Don't submit with failed uploads
            return
        }

        do {
            try await viewModel.submit()
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }

    // MARK: - Position Helpers

    private func positionDataSummary(_ data: [String: AnyCodable]) -> String {
        let items = data.map { key, value -> String in
            let valueStr: String
            switch value.value {
            case let str as String:
                valueStr = str
            case let num as Int:
                valueStr = String(num)
            case let num as Double:
                valueStr = String(format: "%.2f", num)
            case let bool as Bool:
                valueStr = bool ? "Yes" : "No"
            default:
                valueStr = String(describing: value.value)
            }
            return "\(key): \(valueStr)"
        }
        return items.joined(separator: ", ")
    }

    // MARK: - Image Helpers

    private func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Save to temp file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")
                do {
                    try data.write(to: tempURL)
                    viewModel.addImage(from: tempURL)
                } catch {
                    print("Failed to save temp image: \(error)")
                }
            }
        }

        // Clear selection
        selectedPhotos = []

        // Auto-upload
        await viewModel.uploadPendingImages()
    }
}

#Preview {
    NavigationStack {
        ItemFormSheet()
    }
}
