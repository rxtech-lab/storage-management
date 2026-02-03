//
//  AuthorListView.swift
//  RxStorage
//
//  Author list view
//

import RxStorageCore
import SwiftUI

/// Author list view
struct AuthorListView: View {
    @Binding var selectedAuthor: Author?
    let horizontalSizeClass: UserInterfaceSizeClass

    @State private var viewModel = AuthorListViewModel()
    @State private var showingCreateSheet = false
    @State private var isRefreshing = false
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var authorToDelete: Author?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedAuthor: Binding<Author?> = .constant(nil)) {
        self.horizontalSizeClass = horizontalSizeClass
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
        .task {
            // Listen for author events and refresh
            for await event in eventViewModel.stream {
                switch event {
                case .authorCreated, .authorUpdated, .authorDeleted:
                    isRefreshing = true
                    await viewModel.refreshAuthors()
                    isRefreshing = false
                default:
                    break
                }
            }
        }
        .overlay {
            if isRefreshing {
                LoadingOverlay(title: "Refreshing...")
            }
        }
        .confirmationDialog(
            title: "Delete Author",
            message: "Are you sure you want to delete \"\(authorToDelete?.name ?? "")\"? This action cannot be undone.",
            confirmButtonTitle: "Delete",
            isPresented: $showDeleteConfirmation,
            onConfirm: {
                if let author = authorToDelete {
                    Task {
                        if let deletedId = try? await viewModel.deleteAuthor(author) {
                            eventViewModel.emit(.authorDeleted(id: deletedId))
                        }
                        authorToDelete = nil
                    }
                }
            },
            onCancel: { authorToDelete = nil }
        )
    }

    // MARK: - Authors List

    private var authorsList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedAuthor) {
            ForEach(viewModel.authors) { author in
                NavigationLink(value: author) {
                    AuthorRow(author: author)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        authorToDelete = author
                        showDeleteConfirmation = true
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
        AuthorListView(horizontalSizeClass: .compact, selectedAuthor: $selectedAuthor)
    }
}
