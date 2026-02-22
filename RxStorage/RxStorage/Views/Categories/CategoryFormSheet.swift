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
    @Environment(EventViewModel.self) private var eventViewModel

    init(category: RxStorageCore.Category? = nil, onCreated: ((RxStorageCore.Category) -> Void)? = nil) {
        self.category = category
        self.onCreated = onCreated
        _viewModel = State(initialValue: CategoryFormViewModel(category: category))
    }

    var body: some View {
        Form {
            Section("Information") {
                TextField("Name", text: $viewModel.name)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
                    .accessibilityIdentifier("category-form-name-field")

                TextField("Description", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .accessibilityIdentifier("category-form-description-field")
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
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category == nil ? "New Category" : "Edit Category")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("category-form-cancel-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(category == nil ? "Create" : "Save") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("category-form-submit-button")
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
            let savedCategory = try await viewModel.submit()
            // Emit event based on create vs update
            if category == nil {
                eventViewModel.emit(.categoryCreated(id: savedCategory.id))
            } else {
                eventViewModel.emit(.categoryUpdated(id: savedCategory.id))
            }
            // If callback provided, call with created category
            onCreated?(savedCategory)
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
