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

    @State private var viewModel = PositionSchemaListViewModel()
    @State private var showingCreateSheet = false
    @State private var isRefreshing = false
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var schemaToDelete: PositionSchema?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(selectedSchema: Binding<PositionSchema?> = .constant(nil)) {
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
                        if let deletedId = try? await viewModel.deleteSchema(schema) {
                            eventViewModel.emit(.positionSchemaDeleted(id: deletedId))
                        }
                        schemaToDelete = nil
                    }
                }
            },
            onCancel: { schemaToDelete = nil }
        )
    }

    // MARK: - Schemas List

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var schemasList: some View {
        List {
            ForEach(viewModel.schemas) { schema in
                if horizontalSizeClass == .compact {
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
                } else {
                    Button {
                        selectedSchema = schema
                    } label: {
                        PositionSchemaRow(schema: schema)
                    }
                    .listRowBackground(selectedSchema?.id == schema.id ? Color.accentColor.opacity(0.2) : nil)
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
        PositionSchemaListView(selectedSchema: $selectedSchema)
    }
}
