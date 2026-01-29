//
//  ItemFormSheet.swift
//  RxStorage
//
//  Item create/edit form with inline entity creation
//

import SwiftUI
import RxStorageCore

/// Item form sheet for creating or editing items
struct ItemFormSheet: View {
    let item: StorageItem?

    @State private var viewModel: ItemFormViewModel
    @Environment(\.dismiss) private var dismiss

    // Inline creation sheets
    @State private var showingCategorySheet = false
    @State private var showingLocationSheet = false
    @State private var showingAuthorSheet = false

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
                    .lineLimit(3...6)

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
        .task {
            await viewModel.loadReferenceData()
        }
        .overlay {
            if viewModel.isSubmitting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            try await viewModel.submit()
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }
}

#Preview {
    NavigationStack {
        ItemFormSheet()
    }
}
