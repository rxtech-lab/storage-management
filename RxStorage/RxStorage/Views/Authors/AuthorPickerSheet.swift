//
//  AuthorPickerSheet.swift
//  RxStorage
//
//  Searchable author picker sheet with pagination
//

import RxStorageCore
import SwiftUI

/// Searchable author picker sheet
struct AuthorPickerSheet: View {
    let selectedId: Int?
    let onSelect: (Author?) -> Void

    @State private var viewModel = AuthorPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading authors...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.displayItems.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Authors" : "No Results",
                    systemImage: "person.circle",
                    description: Text(viewModel.searchText.isEmpty ? "Create an author first" : "No authors found")
                )
            } else {
                authorList
            }
        }
        .navigationTitle("Select Author")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") {
                    onSelect(nil)
                    dismiss()
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search authors")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .task {
            await viewModel.loadAuthors()
        }
    }

    private var authorList: some View {
        List {
            ForEach(viewModel.displayItems) { author in
                Button {
                    onSelect(author)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(author.name)
                                .foregroundStyle(.primary)
                            if let bio = author.bio {
                                Text(bio)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if author.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .onAppear {
                    if viewModel.shouldLoadMore(for: author) {
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
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AuthorPickerSheet(selectedId: nil) { _ in }
    }
}
