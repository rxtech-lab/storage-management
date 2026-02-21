//
//  ItemFilterSheet.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/3/26.
//

import RxStorageCore
import SwiftUI

/// Item filter sheet
struct ItemFilterSheet: View {
    @Binding var filters: ItemFilters
    let onApply: () -> Void

    @State private var viewModel: ItemFilterViewModel
    @Environment(\.dismiss) private var dismiss

    // Picker sheet states
    @State private var showingCategoryPicker = false
    @State private var showingLocationPicker = false
    @State private var showingAuthorPicker = false

    init(filters: Binding<ItemFilters>, onApply: @escaping () -> Void) {
        _filters = filters
        self.onApply = onApply
        _viewModel = State(initialValue: ItemFilterViewModel(initialFilters: filters.wrappedValue))
    }

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading filters...")
                        Spacer()
                    }
                }
            } else {
                // Visibility Section
                Section("Visibility") {
                    Picker("Visibility", selection: $viewModel.selectedVisibility) {
                        Text("All").tag(nil as RxStorageCore.Visibility?)
                        Text("Public").tag(RxStorageCore.Visibility.publicAccess as RxStorageCore.Visibility?)
                        Text("Private").tag(RxStorageCore.Visibility.privateAccess as RxStorageCore.Visibility?)
                    }
                    .accessibilityIdentifier("item-filter-visibility-picker")
                }

                // Category Section
                Section("Category") {
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
                }

                // Location Section
                Section("Location") {
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
                }

                // Author Section
                Section("Author") {
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
                }

                // Clear Filters Button
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        viewModel.clearFilters()
                    }
                    .disabled(!viewModel.hasActiveFilters)
                    .accessibilityIdentifier("item-filter-clear-button")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Filters")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("item-filter-cancel-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filters = viewModel.buildFilters()
                        onApply()
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("item-filter-apply-button")
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                NavigationStack {
                    CategoryPickerSheet(selectedId: viewModel.selectedCategoryId) { category in
                        viewModel.selectedCategoryId = category?.id
                    }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                NavigationStack {
                    LocationPickerSheet(selectedId: viewModel.selectedLocationId) { location in
                        viewModel.selectedLocationId = location?.id
                    }
                }
            }
            .sheet(isPresented: $showingAuthorPicker) {
                NavigationStack {
                    AuthorPickerSheet(selectedId: viewModel.selectedAuthorId) { author in
                        viewModel.selectedAuthorId = author?.id
                    }
                }
            }
            .task {
                await viewModel.loadFilterOptions()
            }
    }

    // MARK: - Computed Properties

    private var selectedCategoryName: String {
        guard let id = viewModel.selectedCategoryId,
              let category = viewModel.categories.first(where: { $0.id == id })
        else {
            return "All Categories"
        }
        return category.name
    }

    private var selectedLocationName: String {
        guard let id = viewModel.selectedLocationId,
              let location = viewModel.locations.first(where: { $0.id == id })
        else {
            return "All Locations"
        }
        return location.title
    }

    private var selectedAuthorName: String {
        guard let id = viewModel.selectedAuthorId,
              let author = viewModel.authors.first(where: { $0.id == id })
        else {
            return "All Authors"
        }
        return author.name
    }
}
