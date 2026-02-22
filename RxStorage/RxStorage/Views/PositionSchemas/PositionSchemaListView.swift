//
//  PositionSchemaListView.swift
//  RxStorage
//
//  Position schema list view
//

import OpenAPIRuntime
import RxStorageCore
import SwiftUI

/// Position schema list view
struct PositionSchemaListView: View {
    @Binding var selectedSchema: PositionSchema?
    let horizontalSizeClass: UserInterfaceSizeClass

    @State private var viewModel = PositionSchemaListViewModel()
    @State private var showingCreateSheet = false
    @State private var isRefreshing = false
    @State private var errorViewModel = ErrorViewModel()
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var schemaToDelete: PositionSchema?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedSchema: Binding<PositionSchema?> = .constant(nil)) {
        self.horizontalSizeClass = horizontalSizeClass
        _selectedSchema = selectedSchema
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.schemas.isEmpty {
                ProgressView("Loading schemas...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.schemas.isEmpty {
                ContentUnavailableView(
                    "No Position Schemas",
                    systemImage: "doc.text",
                    description: Text(viewModel.searchText.isEmpty ? "Create your first schema" : "No results found")
                )
            } else {
                schemasList
            }
        }
        .navigationTitle("Position Schemas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Schema", systemImage: "plus")
                }
                .accessibilityIdentifier("schema-list-new-button")
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search schemas")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .refreshable {
            await viewModel.refreshSchemas()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                PositionSchemaFormSheet()
            }
        }
        .task {
            await viewModel.fetchSchemas()
        }
        .task {
            // Listen for position schema events and refresh
            for await event in eventViewModel.stream {
                switch event {
                case .positionSchemaCreated, .positionSchemaUpdated, .positionSchemaDeleted:
                    isRefreshing = true
                    await viewModel.refreshSchemas()
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
            title: "Delete Schema",
            message: "Are you sure you want to delete \"\(schemaToDelete?.name ?? "")\"? This action cannot be undone.",
            confirmButtonTitle: "Delete",
            isPresented: $showDeleteConfirmation,
            onConfirm: {
                if let schema = schemaToDelete {
                    Task {
                        do {
                            let deletedId = try await viewModel.deleteSchema(schema)
                            eventViewModel.emit(.positionSchemaDeleted(id: deletedId))
                        } catch {
                            errorViewModel.showError(error)
                        }
                        schemaToDelete = nil
                    }
                }
            },
            onCancel: { schemaToDelete = nil }
        )
        .onChange(of: viewModel.error != nil) { _, hasError in
            if hasError, let error = viewModel.error {
                errorViewModel.showError(error)
            }
        }
        .showViewModelError(errorViewModel)
    }

    // MARK: - Schemas List

    private var schemasList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedSchema) {
            ForEach(viewModel.schemas) { schema in
                NavigationLink(value: schema) {
                    PositionSchemaRow(schema: schema)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        schemaToDelete = schema
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if shouldLoadMore(for: schema) {
                        Task {
                            await viewModel.loadMoreSchemas()
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

    private func shouldLoadMore(for schema: PositionSchema) -> Bool {
        guard let index = viewModel.schemas.firstIndex(where: { $0.id == schema.id }) else {
            return false
        }
        let threshold = 3
        return index >= viewModel.schemas.count - threshold &&
            viewModel.hasNextPage &&
            !viewModel.isLoadingMore &&
            !viewModel.isLoading
    }
}

/// Position schema row in list
struct PositionSchemaRow: View {
    let schema: PositionSchema

    /// Count of properties in the JSON schema
    private var fieldCount: Int {
        // The schema is an OpenAPIObjectContainer with additionalProperties
        // JSON Schema stores fields in the "properties" key
        if let properties = schema.schema.additionalProperties["properties"]?.value as? [String: Any] {
            return properties.count
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schema.name)
                .font(.headline)
                .accessibilityIdentifier("schema-row")

            Text("\(fieldCount) fields")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var selectedSchema: PositionSchema?
    NavigationStack {
        PositionSchemaListView(horizontalSizeClass: .compact, selectedSchema: $selectedSchema)
    }
}
