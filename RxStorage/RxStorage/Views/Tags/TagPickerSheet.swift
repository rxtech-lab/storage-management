//
//  TagPickerSheet.swift
//  RxStorage
//
//  Searchable tag picker sheet with pagination
//

import RxStorageCore
import SwiftUI

/// Searchable tag picker sheet for adding tags to items
struct TagPickerSheet: View {
    let existingTagIds: Set<String>
    let onSelect: (Tag) async -> Void
    var onDeselect: ((Tag) async -> Void)?

    @State private var viewModel = TagPickerViewModel()
    @State private var showingCreateSheet = false
    @State private var editingTag: Tag?
    @State private var tagToDelete: Tag?
    @State private var showDeleteConfirmation = false
    @State private var selectedTagIds: Set<String> = []
    @State private var isUpdating = false
    @Environment(\.dismiss) private var dismiss

    private let tagService = TagService()

    var body: some View {
        ZStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading tags...")
                } else if viewModel.isSearching {
                    ProgressView("Searching...")
                } else if viewModel.displayItems.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Matching Tags",
                        systemImage: "tag",
                        description: Text("No tags found matching your search")
                    )
                } else if viewModel.displayItems.isEmpty {
                    ContentUnavailableView(
                        "No Tags Available",
                        systemImage: "tag",
                        description: Text("Create a tag from the Tags page first")
                    )
                } else {
                    tagList
                }
            }

            if isUpdating {
                LoadingOverlay(title: "Updating...")
            }
        }
        .navigationTitle("Manage Tags")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search tags")
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.search(newValue)
            }
            .task {
                await viewModel.loadTags()
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationStack {
                    TagFormSheet { _ in
                        Task { await viewModel.loadTags() }
                    }
                }
            }
            .sheet(item: $editingTag) { tag in
                NavigationStack {
                    TagFormSheet(tag: tag) { _ in
                        Task { await viewModel.loadTags() }
                    }
                }
            }
            .confirmationDialog(
                title: "Delete Tag",
                message: "Are you sure you want to delete \"\(tagToDelete?.title ?? "")\"? This will remove it from all items.",
                confirmButtonTitle: "Delete",
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    guard let tag = tagToDelete else { return }
                    Task {
                        isUpdating = true
                        defer { isUpdating = false }
                        do {
                            try await tagService.deleteTag(id: tag.id)
                            await viewModel.loadTags()
                        } catch {}
                    }
                },
                onCancel: { tagToDelete = nil }
            )
    }

    private func isTagAdded(_ tag: Tag) -> Bool {
        existingTagIds.contains(tag.id) || selectedTagIds.contains(tag.id)
    }

    private var tagList: some View {
        List {
            ForEach(viewModel.displayItems) { tag in
                let added = isTagAdded(tag)
                Button {
                    guard !isUpdating else { return }
                    Task {
                        isUpdating = true
                        defer { isUpdating = false }
                        if added {
                            // Allow deselection if onDeselect is provided
                            if let onDeselect = onDeselect {
                                await onDeselect(tag)
                                selectedTagIds.remove(tag.id)
                            }
                        } else {
                            await onSelect(tag)
                            selectedTagIds.insert(tag.id)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: tag.color) ?? .gray)
                            .frame(width: 12, height: 12)

                        Text(tag.title)
                            .foregroundStyle(.primary)

                        Spacer()

                        if added {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        tagToDelete = tag
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        editingTag = tag
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .disabled(isUpdating)
                .onAppear {
                    if viewModel.shouldLoadMore(for: tag) {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}

// MARK: - Color Extension

private extension Color {
    init?(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16)
        else { return nil }
        self.init(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TagPickerSheet(
            existingTagIds: ["tag-1"],
            onSelect: { tag async in
                print("Selected tag: \(tag.title)")
            },
            onDeselect: { tag async in
                print("Deselected tag: \(tag.title)")
            }
        )
    }
}
