//
//  AuthorFormSheet.swift
//  RxStorage
//
//  Author create/edit form
//

import SwiftUI
import RxStorageCore

/// Author form sheet for creating or editing authors
struct AuthorFormSheet: View {
    let author: Author?
    let onCreated: ((Author) -> Void)?

    @State private var viewModel: AuthorFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(EventViewModel.self) private var eventViewModel

    init(author: Author? = nil, onCreated: ((Author) -> Void)? = nil) {
        self.author = author
        self.onCreated = onCreated
        _viewModel = State(initialValue: AuthorFormViewModel(author: author))
    }

    var body: some View {
        Form {
            Section("Information") {
                TextField("Name", text: $viewModel.name)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif

                TextField("Bio", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(3...6)
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
        .navigationTitle(author == nil ? "New Author" : "Edit Author")
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
                Button(author == nil ? "Create" : "Save") {
                    Task {
                        await submitForm()
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
                    .background {
                        #if os(iOS)
                        Color(uiColor: .systemBackground)
                        #elseif os(macOS)
                        Color(nsColor: .windowBackgroundColor)
                        #endif
                    }
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            let savedAuthor = try await viewModel.submit()
            // Emit event based on create vs update
            if author == nil {
                eventViewModel.emit(.authorCreated(id: savedAuthor.id))
            } else {
                eventViewModel.emit(.authorUpdated(id: savedAuthor.id))
            }
            // If callback provided, call with created author
            onCreated?(savedAuthor)
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }
}

#Preview {
    NavigationStack {
        AuthorFormSheet()
    }
}
