//
//  ItemFormSheet.swift
//  RxStorage
//
//  Item create/edit form with inline entity creation
//

import OpenAPIRuntime
import PhotosUI
import RxStorageCore
import SwiftUI

/// Item form sheet for creating or editing items
struct ItemFormSheet: View {
    let item: StorageItem?

    @State private var viewModel: ItemFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(EventViewModel.self) private var eventViewModel

    // Inline creation sheets
    @State private var showingCategorySheet = false
    @State private var showingLocationSheet = false
    @State private var showingAuthorSheet = false
    @State private var showingPositionSheet = false

    // Picker sheets
    @State private var showingCategoryPicker = false
    @State private var showingLocationPicker = false
    @State private var showingAuthorPicker = false
    @State private var showingParentItemPicker = false

    // Image source
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    // Selected entities from pickers (for display names)
    @State private var selectedCategory: RxStorageCore.Category?
    @State private var selectedLocation: RxStorageCore.Location?
    @State private var selectedAuthor: RxStorageCore.Author?
    @State private var selectedParentItem: RxStorageCore.StorageItem?

    /// Photo picker
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(item: StorageItem? = nil) {
        self.item = item
        _viewModel = State(initialValue: ItemFormViewModel(item: item))
    }

    var body: some View {
        Form {
            basicInfoSection
            categorySection
            locationSection
            authorSection
            hierarchySection
            privacySection
            imagesSection
            positionsSection
            validationErrorsSection
        }
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(item == nil ? "New Item" : "Edit Item")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("item-form-cancel-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "Create" : "Save") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("item-form-submit-button")
                }
            }
            .sheet(isPresented: $showingCategorySheet) {
                NavigationStack {
                    CategoryFormSheet { newCategory in
                        viewModel.selectedCategoryId = newCategory.id
                        selectedCategory = newCategory
                    }
                }
            }
            .sheet(isPresented: $showingLocationSheet) {
                NavigationStack {
                    LocationFormSheet { newLocation in
                        viewModel.selectedLocationId = newLocation.id
                        selectedLocation = newLocation
                    }
                }
            }
            .sheet(isPresented: $showingAuthorSheet) {
                NavigationStack {
                    AuthorFormSheet { newAuthor in
                        viewModel.selectedAuthorId = newAuthor.id
                        selectedAuthor = newAuthor
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
            .sheet(isPresented: $showingCategoryPicker) {
                NavigationStack {
                    CategoryPickerSheet(selectedId: viewModel.selectedCategoryId) { category in
                        viewModel.selectedCategoryId = category?.id
                        selectedCategory = category
                    }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                NavigationStack {
                    LocationPickerSheet(selectedId: viewModel.selectedLocationId) { location in
                        viewModel.selectedLocationId = location?.id
                        selectedLocation = location
                    }
                }
            }
            .sheet(isPresented: $showingAuthorPicker) {
                NavigationStack {
                    AuthorPickerSheet(selectedId: viewModel.selectedAuthorId) { author in
                        viewModel.selectedAuthorId = author?.id
                        selectedAuthor = author
                    }
                }
            }
            .sheet(isPresented: $showingParentItemPicker) {
                NavigationStack {
                    ParentItemPickerSheet(
                        selectedId: viewModel.selectedParentId,
                        excludeItemId: item?.id
                    ) { parentItem in
                        viewModel.selectedParentId = parentItem?.id
                        selectedParentItem = parentItem
                    }
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

    // MARK: - Form Sections

    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Title", text: $viewModel.title)
            #if os(iOS)
                .textInputAutocapitalization(.words)
            #endif
                .accessibilityIdentifier("item-form-title-field")

            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(3 ... 6)
                .accessibilityIdentifier("item-form-description-field")

            TextField("Price", text: $viewModel.price)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
                .accessibilityIdentifier("item-form-price-field")
        }
    }

    private var categorySection: some View {
        Section {
            Button {
                showingCategoryPicker = true
            } label: {
                HStack {
                    Text("Category")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedCategoryName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("item-form-category-picker")

            Button {
                showingCategorySheet = true
            } label: {
                Label("Create New Category", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("item-form-create-category-button")
        } header: {
            Text("Category")
        }
    }

    private var locationSection: some View {
        Section {
            Button {
                showingLocationPicker = true
            } label: {
                HStack {
                    Text("Location")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedLocationName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("item-form-location-picker")

            Button {
                showingLocationSheet = true
            } label: {
                Label("Create New Location", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("item-form-create-location-button")
        } header: {
            Text("Location")
        }
    }

    private var authorSection: some View {
        Section {
            Button {
                showingAuthorPicker = true
            } label: {
                HStack {
                    Text("Author")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedAuthorName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("item-form-author-picker")

            Button {
                showingAuthorSheet = true
            } label: {
                Label("Create New Author", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("item-form-create-author-button")
        } header: {
            Text("Author")
        }
    }

    private var hierarchySection: some View {
        Section("Hierarchy") {
            Button {
                showingParentItemPicker = true
            } label: {
                HStack {
                    Text("Parent Item")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedParentItemName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("item-form-parent-picker")
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Picker("Visibility", selection: $viewModel.visibility) {
                Text("Public").tag(Visibility.publicAccess)
                Text("Private").tag(Visibility.privateAccess)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("item-form-visibility-picker")
        }
    }

    private var imagesSection: some View {
        Section("Images") {
            // Existing images
            ForEach(Array(viewModel.existingImages.enumerated()), id: \.element.id) { index, imageRef in
                HStack {
                    AsyncImage(url: URL(string: imageRef.url)) { image in
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
                pendingUploadRow(pending)
            }

            // Add images menu with camera and library options
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
            .accessibilityIdentifier("item-form-add-images-button")
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                await handleSelectedPhotos(newValue)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView { image in
                Task {
                    await handleCapturedImage(image)
                }
            }
        }
        #endif
    }

    private func pendingUploadRow(_ pending: PendingUpload) -> some View {
        HStack {
            // Local preview from file URL
            if let image = loadImage(from: pending.localURL) {
                #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif
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
                } else if case let .failed(error) = pending.status {
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

    private var positionsSection: some View {
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
    }

    @ViewBuilder
    private var validationErrorsSection: some View {
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

    // MARK: - Computed Properties

    private var selectedCategoryName: String {
        // Check if a new selection was made via picker
        if let category = selectedCategory {
            return category.name
        }
        // Use item's embedded FK object for initial display
        if let categoryRef = item?.category?.value1 {
            return categoryRef.name
        }
        return "None"
    }

    private var selectedLocationName: String {
        if let location = selectedLocation {
            return location.title
        }
        if let locationRef = item?.location?.value1 {
            return locationRef.title
        }
        return "None"
    }

    private var selectedAuthorName: String {
        if let author = selectedAuthor {
            return author.name
        }
        if let authorRef = item?.author?.value1 {
            return authorRef.name
        }
        return "None"
    }

    private var selectedParentItemName: String {
        if let parentItem = selectedParentItem {
            return parentItem.title
        }
        // Parent is not embedded in API response - shows "None" until picker is used
        return "None"
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
            let savedItem = try await viewModel.submit()
            // Emit event based on create vs update
            if item == nil {
                eventViewModel.emit(.itemCreated(id: savedItem.id))
            } else {
                eventViewModel.emit(.itemUpdated(id: savedItem.id))
            }
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }

    // MARK: - Position Helpers

    /// Summarize position data from generated dataPayload type
    private func positionDataSummary(_ data: Position.dataPayload) -> String {
        let items = data.additionalProperties.map { key, value -> String in
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
                valueStr = String(describing: value.value ?? "")
            }
            return "\(key): \(valueStr)"
        }
        return items.joined(separator: ", ")
    }

    /// Summarize position data from AnyCodable dictionary (for pending positions)
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

    #if os(iOS)
        private func loadImage(from url: URL) -> UIImage? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }

    #elseif os(macOS)
        private func loadImage(from url: URL) -> NSImage? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)
        }
    #endif

    #if os(iOS)
        private func handleCapturedImage(_ image: UIImage) async {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            do {
                try data.write(to: tempURL)
                viewModel.addImage(from: tempURL)
                await viewModel.uploadPendingImages()
            } catch {
                print("Failed to save captured image: \(error)")
            }
        }
    #endif

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
