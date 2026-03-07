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
    let onSelect: (Tag) -> Void

    @State private var viewModel = TagPickerViewModel()
    @State private var showingCreateSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading tags...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.availableTags.isEmpty && !viewModel.searchText.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Matching Tags",
                        systemImage: "tag",
                        description: Text("No tags found matching your search")
                    )
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Create \"\(viewModel.searchText)\"", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.availableTags.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Tags Available",
                        systemImage: "tag",
                        description: Text("Create a tag to get started")
                    )
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Create New Tag", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                tagList
            }
        }
        .navigationTitle("Add Tag")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
                viewModel.existingTagIds = existingTagIds
                await viewModel.loadTags()
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationStack {
                    TagFormSheet(initialTitle: viewModel.searchText) { tag in
                        onSelect(tag)
                        dismiss()
                    }
                }
            }
    }

    private var tagList: some View {
        List {
            ForEach(viewModel.availableTags) { tag in
                Button {
                    onSelect(tag)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: tag.color) ?? .gray)
                            .frame(width: 12, height: 12)

                        Text(tag.title)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(tag.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(isLightColor(tag.color) ? .black : .white)
                            .background(Color(hex: tag.color) ?? .gray)
                            .clipShape(Capsule())
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

    private func isLightColor(_ hex: String) -> Bool {
        let color = hex.replacingOccurrences(of: "#", with: "")
        guard color.count == 6 else { return true }
        guard let r = UInt8(color.prefix(2), radix: 16),
              let g = UInt8(color.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(color.dropFirst(4).prefix(2), radix: 16)
        else { return true }
        let luminance = 0.2126 * Double(r) / 255.0 + 0.7152 * Double(g) / 255.0 + 0.0722 * Double(b) / 255.0
        return luminance > 0.5
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
