//
//  AuthorListView.swift
//  RxStorage
//
//  Author list view
//

import SwiftUI
import RxStorageCore

/// Author list view
struct AuthorListView: View {
    @Binding var selectedAuthor: Author?

    @State private var viewModel = AuthorListViewModel()
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.authors.isEmpty {
                ProgressView("Loading authors...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.authors.isEmpty {
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
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
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
        List(selection: $selectedAuthor) {
            ForEach(viewModel.authors) { author in
                NavigationLink(value: author) {
                    AuthorRow(author: author)
                }
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
    @Previewable @State var selectedAuthor: Author?
    NavigationStack {
        AuthorListView(selectedAuthor: $selectedAuthor)
    }
}
