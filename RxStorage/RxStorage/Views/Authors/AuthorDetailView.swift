//
//  AuthorDetailView.swift
//  RxStorage
//
//  Author detail view
//

import RxStorageCore
import SwiftUI

/// Author detail view
struct AuthorDetailView: View {
    let authorId: String

    @Environment(AuthorDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false
    @State private var showingItemsSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let author = viewModel.author {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        authorHeader(author)
                            .cardStyle()

                        // Details
                        authorDetails(author)
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
                    "Error Loading Author",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.author?.name ?? "Author")
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
                if let author = viewModel.author {
                    NavigationStack {
                        AuthorFormSheet(author: author)
                    }
                }
            }
            .sheet(isPresented: $showingItemsSheet) {
                EntityItemsListSheet(filter: .author(id: authorId))
            }
            .task(id: authorId) {
                await viewModel.fetchAuthor(id: authorId)
            }
    }

    // MARK: - Author Header

    private func authorHeader(_ author: Author) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(author.name)
                .font(.title2)
                .fontWeight(.bold)

            if let bio = author.bio {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Author Details

    private func authorDetails(_ author: Author) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(
                label: "Created",
                value: author.createdAt.formatted(date: .abbreviated, time: .shortened),
                icon: "calendar"
            )

            DetailRow(
                label: "Updated",
                value: author.updatedAt.formatted(date: .abbreviated, time: .shortened),
                icon: "clock"
            )
        }
    }
}

#Preview {
    NavigationStack {
        AuthorDetailView(authorId: "1")
            .environment(AuthorDetailViewModel())
    }
}
