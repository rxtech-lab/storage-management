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
    let onApply: () async -> Void

    @State private var viewModel: ItemFilterViewModel
    @State private var isApplying = false
    @Environment(\.dismiss) private var dismiss

    // Picker sheet states
    @State private var showingTagPicker = false
    @State private var showingCategoryPicker = false
    @State private var showingLocationPicker = false
    @State private var showingAuthorPicker = false

    // Date filter toggle states (to enable/disable date filtering)
    @State private var isItemDateFilterEnabled: Bool
    @State private var isExpiresAtFilterEnabled: Bool

    init(filters: Binding<ItemFilters>, onApply: @escaping () async -> Void) {
        _filters = filters
        self.onApply = onApply
        _viewModel = State(initialValue: ItemFilterViewModel(initialFilters: filters.wrappedValue))
        _isItemDateFilterEnabled = State(initialValue: filters.wrappedValue.itemDateOp != nil)
        _isExpiresAtFilterEnabled = State(initialValue: filters.wrappedValue.expiresAtOp != nil)
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

                // Tags Section
                Section("Tags") {
                    Button {
                        showingTagPicker = true
                    } label: {
                        HStack {
                            Text("Tags")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(selectedTagsSummary)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                // Item Date Filter Section
                Section("Item Date") {
                    Toggle("Filter by Item Date", isOn: $isItemDateFilterEnabled)
                        .onChange(of: isItemDateFilterEnabled) { _, enabled in
                            if !enabled {
                                viewModel.itemDateOp = nil
                                viewModel.itemDateValue = nil
                            } else if viewModel.itemDateOp == nil {
                                viewModel.itemDateOp = .lte
                                viewModel.itemDateValue = Date()
                            }
                        }

                    if isItemDateFilterEnabled {
                        Picker("Condition", selection: Binding(
                            get: { viewModel.itemDateOp ?? .lte },
                            set: { viewModel.itemDateOp = $0 }
                        )) {
                            ForEach(ComparisonOperator.allCases) { op in
                                Text(op.displayName).tag(op)
                            }
                        }

                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { viewModel.itemDateValue ?? Date() },
                                set: { viewModel.itemDateValue = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // Deadline Filter Section
                Section("Deadline") {
                    Toggle("Filter by Deadline", isOn: $isExpiresAtFilterEnabled)
                        .onChange(of: isExpiresAtFilterEnabled) { _, enabled in
                            if !enabled {
                                viewModel.expiresAtOp = nil
                                viewModel.expiresAtValue = nil
                            } else if viewModel.expiresAtOp == nil {
                                viewModel.expiresAtOp = .lte
                                viewModel.expiresAtValue = Date()
                            }
                        }

                    if isExpiresAtFilterEnabled {
                        Picker("Condition", selection: Binding(
                            get: { viewModel.expiresAtOp ?? .lte },
                            set: { viewModel.expiresAtOp = $0 }
                        )) {
                            ForEach(ComparisonOperator.allCases) { op in
                                Text(op.displayName).tag(op)
                            }
                        }

                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { viewModel.expiresAtValue ?? Date() },
                                set: { viewModel.expiresAtValue = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // Clear Filters Button
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        viewModel.clearFilters()
                        isItemDateFilterEnabled = false
                        isExpiresAtFilterEnabled = false
                    }
                    .disabled(!viewModel.hasActiveFilters)
                    .accessibilityIdentifier("item-filter-clear-button")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if isApplying {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Applying filters...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .allowsHitTesting(!isApplying)
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
                        isApplying = true
                        filters = viewModel.buildFilters()
                        Task {
                            await onApply()
                            isApplying = false
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading || isApplying)
                    .accessibilityIdentifier("item-filter-apply-button")
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                NavigationStack {
                    TagFilterPickerSheet(selectedTagIds: $viewModel.selectedTagIds)
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

    private var selectedTagsSummary: String {
        if viewModel.selectedTagIds.isEmpty {
            return "All Tags"
        }
        let count = viewModel.selectedTagIds.count
        return "\(count) selected"
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
