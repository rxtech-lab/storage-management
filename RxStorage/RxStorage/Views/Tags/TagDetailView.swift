//
//  TagDetailView.swift
//  RxStorage
//
//  Tag detail view
//

import RxStorageCore
import SwiftUI

/// Tag detail view
struct TagDetailView: View {
    let tagId: String

    @Environment(TagDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false
    @State private var showingItemsSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let tag = viewModel.tag {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        tagHeader(tag)
                            .cardStyle()

                        // Details
                        tagDetails(tag)
                            .cardStyle()

                        // Items
                        EntityItemsCard(
                            items: viewModel.items,
                            totalItems: viewModel.totalItems,
                            onSeeAll: { showingItemsSheet = true }
                        )
                    }
                    .padding()
                }
                .background(Color.systemGroupedBackground)
                .navigationDestination(for: StorageItem.self) { item in
                    ItemDetailView(itemId: item.id)
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading Tag",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.tag?.title ?? "Tag")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let tag = viewModel.tag {
                    NavigationStack {
                        TagFormSheet(tag: tag) { _ in
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingItemsSheet) {
                EntityItemsListSheet(filter: .tag(id: tagId))
            }
            .task(id: tagId) {
                await viewModel.fetchTag(id: tagId)
            }
    }

    // MARK: - Tag Header

    private func tagHeader(_ tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: tag.color) ?? .gray)
                    .frame(width: 24, height: 24)

                Text(tag.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(tag.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isLightColor(tag.color) ? .black : .white)
                .background(Color(hex: tag.color) ?? .gray)
                .clipShape(Capsule())
        }
    }

    // MARK: - Tag Details

    private func tagDetails(_ tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(
                label: "Color",
                value: tag.color,
                icon: "paintpalette"
            )

            DetailRow(
                label: "Created",
                value: tag.createdAt.formatted(date: .abbreviated, time: .shortened),
                icon: "calendar"
            )

            DetailRow(
                label: "Updated",
                value: tag.updatedAt.formatted(date: .abbreviated, time: .shortened),
                icon: "clock"
            )
        }
    }

    // MARK: - Helpers

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

#Preview {
    NavigationStack {
        TagDetailView(tagId: "1")
            .environment(TagDetailViewModel())
    }
}
