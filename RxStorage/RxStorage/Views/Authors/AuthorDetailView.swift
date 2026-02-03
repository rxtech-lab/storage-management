//
//  AuthorDetailView.swift
//  RxStorage
//
//  Author detail view
//

import SwiftUI
import RxStorageCore

/// Author detail view
struct AuthorDetailView: View {
    let authorId: Int

    @Environment(AuthorDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let author = viewModel.author {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        authorHeader(author)

                        Divider()

                        // Details
                        authorDetails(author)
                    }
                    .padding()
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
        .task(id: authorId) {
            await viewModel.fetchAuthor(id: authorId)
        }
    }

    // MARK: - Author Header

    @ViewBuilder
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

    @ViewBuilder
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
        AuthorDetailView(authorId: 1)
            .environment(AuthorDetailViewModel())
    }
}
