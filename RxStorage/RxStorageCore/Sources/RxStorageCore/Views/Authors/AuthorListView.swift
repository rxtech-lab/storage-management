//
//  AuthorListView.swift
//  RxStorageCore
//
//  Author list view
//

import SwiftUI

/// Author list view
public struct AuthorListView: View {
    @State private var viewModel = AuthorListViewModel()
    @State private var showingCreateSheet = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.authors.isEmpty {
                ProgressView("Loading authors...")
            } else if viewModel.filteredAuthors.isEmpty {
                ContentUnavailableView(
                    "No Authors",
                    systemImage: "person.circle",
                    description: Text(viewModel.searchText.isEmpty ? "Create your first author" : "No results found")
                )
            } else {
                authorsList
            }
        }
        .navigationTitle("Authors")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Author", systemImage: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search authors")
        .refreshable {
            await viewModel.refreshAuthors()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                AuthorFormSheet()
            }
        }
        .task {
            await viewModel.fetchAuthors()
        }
    }

    // MARK: - Authors List

    private var authorsList: some View {
        List {
            ForEach(viewModel.filteredAuthors) { author in
                AuthorRow(author: author)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteAuthor(author)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

/// Author row in list
struct AuthorRow: View {
    let author: Author

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(author.name)
                .font(.headline)

            if let bio = author.bio {
                Text(bio)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AuthorListView()
    }
}
