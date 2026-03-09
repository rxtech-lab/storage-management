//
//  TagDetailView.swift
//  RxStorage
//
//  Tag detail view showing tag info and related items
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
                        TagFormSheet(tag: tag, onUpdated: { updatedTag in
                            Task { await viewModel.fetchTag(id: updatedTag.id) }
                        })
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
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: tag.color) ?? .gray)
                .frame(width: 24, height: 24)

            Text(tag.title)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()
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
}

#Preview {
    NavigationStack {
        TagDetailView(tagId: "1")
            .environment(TagDetailViewModel())
    }
}
