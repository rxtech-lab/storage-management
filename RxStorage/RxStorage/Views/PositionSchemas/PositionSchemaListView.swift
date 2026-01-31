//
//  PositionSchemaListView.swift
//  RxStorage
//
//  Position schema list view
//

import SwiftUI
import RxStorageCore

/// Position schema list view
struct PositionSchemaListView: View {
    @Binding var selectedSchema: PositionSchema?

    @State private var viewModel = PositionSchemaListViewModel()
    @State private var showingCreateSheet = false

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
    }

    // MARK: - Schemas List

    private var schemasList: some View {
        List(selection: $selectedSchema) {
            ForEach(viewModel.schemas) { schema in
                NavigationLink(value: schema) {
                    PositionSchemaRow(schema: schema)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            try? await viewModel.deleteSchema(schema)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Position schema row in list
struct PositionSchemaRow: View {
    let schema: PositionSchema

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schema.name)
                .font(.headline)

            Text("\(schema.schema.count) fields")
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
