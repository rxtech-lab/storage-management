//
//  CategoryFormSheet.swift
//  RxStorage
//
//  Category create/edit form
//

import RxStorageCore
import SwiftUI

/// Category form sheet for creating or editing categories
struct CategoryFormSheet: View {
    let category: RxStorageCore.Category?
    let onCreated: ((RxStorageCore.Category) -> Void)?

    @State private var viewModel: CategoryFormViewModel
    @Environment(\.dismiss) private var dismiss

    init(category: RxStorageCore.Category? = nil, onCreated: ((RxStorageCore.Category) -> Void)? = nil) {
        self.category = category
        self.onCreated = onCreated
        _viewModel = State(initialValue: CategoryFormViewModel(category: category))
    }

    var body: some View {
        Form {
            Section("Information") {
                TextField("Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)

                TextField("Description", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3 ... 6)
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
        .navigationTitle(category == nil ? "New Category" : "Edit Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(category == nil ? "Create" : "Save") {
                    Task {
                        await submitForm()
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                LoadingOverlay()
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            try await viewModel.submit()
            // If callback provided, fetch the created category
            if let onCreated = onCreated, category == nil {
                // Note: In real implementation, submit should return the created category
                // For now, we'll dismiss and let the parent handle refresh
            }
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }
}

#Preview {
    NavigationStack {
        CategoryFormSheet()
    }
}
