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

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(selectedAuthor: Binding<Author?> = .constant(nil)) {
        _selectedAuthor = selectedAuthor
    }

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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var authorsList: some View {
        List {
            ForEach(viewModel.authors) { author in
                if horizontalSizeClass == .compact {
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
                    .onAppear {
                        if shouldLoadMore(for: author) {
                            Task {
                                await viewModel.loadMoreAuthors()
                            }
                        }
                    }
                } else {
                    Button {
                        selectedAuthor = author
                    } label: {
                        AuthorRow(author: author)
                    }
                    .listRowBackground(selectedAuthor?.id == author.id ? Color.accentColor.opacity(0.2) : nil)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteAuthor(author)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onAppear {
                        if shouldLoadMore(for: author) {
                            Task {
                                await viewModel.loadMoreAuthors()
                            }
                        }
                    }
                }
            }

            // Loading more indicator
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
    }

    // MARK: - Pagination Helper

    private func shouldLoadMore(for author: Author) -> Bool {
        guard let index = viewModel.authors.firstIndex(where: { $0.id == author.id }) else {
            return false
        }
        let threshold = 3
        return index >= viewModel.authors.count - threshold &&
               viewModel.hasNextPage &&
               !viewModel.isLoadingMore &&
               !viewModel.isLoading
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
