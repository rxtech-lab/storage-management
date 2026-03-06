//
//  ContentListSheet.swift
//  RxStorage
//
//  Sheet for browsing all contents of an item with search and pagination
//

import RxStorageCore
import SwiftUI

/// Sheet that displays all contents for an item with search and load more
struct ContentListSheet: View {
    let itemId: String
    @Binding var contentSchemas: [ContentSchema]
    let isViewOnly: Bool

    @State private var viewModel = ContentListViewModel()
    @State private var searchText = ""
    @State private var selectedContent: Content?
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.contents.isEmpty {
                    ProgressView("Loading contents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.contents.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Contents" : "No Results",
                        systemImage: searchText.isEmpty ? "doc.on.doc" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "This item has no content attachments." : "No contents match your search.")
                    )
                } else {
                    contentList
                }
            }
            .navigationTitle("Contents")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .searchable(text: $searchText, prompt: "Search contents")
                .overlay {
                    if isSearching && !viewModel.contents.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    isSearching = true
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        await viewModel.fetchContents(itemId: itemId, search: newValue.isEmpty ? nil : newValue)
                        isSearching = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(item: $selectedContent) { content in
                    NavigationStack {
                        ContentDetailSheet(
                            content: content,
                            contentSchemas: $contentSchemas,
                            onEdit: {},
                            isViewOnly: isViewOnly
                        )
                    }
                }
                .task {
                    await viewModel.fetchContents(itemId: itemId)
                }
        }
    }

    private var contentList: some View {
        List {
            ForEach(viewModel.contents) { content in
                Button {
                    selectedContent = content
                } label: {
                    ContentRowView(content: content)
                }
                .buttonStyle(.plain)
            }

            if viewModel.hasMore {
                Section {
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Button {
                            Task { await viewModel.loadMore() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .foregroundStyle(.blue)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
