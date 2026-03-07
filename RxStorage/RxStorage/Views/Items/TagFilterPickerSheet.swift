//
//  TagFilterPickerSheet.swift
//  RxStorage
//
//  Multi-select tag picker for item filtering
//

import RxStorageCore
import SwiftUI

/// Multi-select tag picker sheet for filtering items by tags
struct TagFilterPickerSheet: View {
    @Binding var selectedTagIds: Set<String>

    @State private var viewModel = TagPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                    description: Text("No tags to filter by")
                )
            } else {
                tagList
            }
        }
        .navigationTitle("Filter by Tags")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        selectedTagIds.removeAll()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search tags")
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.search(newValue)
            }
            .task {
                // Don't filter out any tags - show all for selection
                viewModel.existingTagIds = []
                await viewModel.loadTags()
            }
    }

    private var tagList: some View {
        List {
            ForEach(viewModel.displayItems) { tag in
                Button {
                    if selectedTagIds.contains(tag.id) {
                        selectedTagIds.remove(tag.id)
                    } else {
                        selectedTagIds.insert(tag.id)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: tag.color) ?? .gray)
                            .frame(width: 12, height: 12)

                        Text(tag.title)
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedTagIds.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
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
