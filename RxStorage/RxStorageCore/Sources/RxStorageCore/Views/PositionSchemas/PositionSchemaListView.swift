//
//  PositionSchemaListView.swift
//  RxStorageCore
//
//  Position schema list view
//

import SwiftUI

/// Position schema list view
public struct PositionSchemaListView: View {
    @State private var viewModel = PositionSchemaListViewModel()
    @State private var showingCreateSheet = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.schemas.isEmpty {
                ProgressView("Loading schemas...")
            } else if viewModel.filteredSchemas.isEmpty {
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
        List {
            ForEach(viewModel.filteredSchemas) { schema in
                PositionSchemaRow(schema: schema)
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
    NavigationStack {
        PositionSchemaListView()
    }
}
