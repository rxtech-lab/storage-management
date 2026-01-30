//
//  PositionSchemaDetailView.swift
//  RxStorage
//
//  Position schema detail view
//

import JsonSchemaEditor
import JSONSchema
import RxStorageCore
import SwiftUI

/// Position schema detail view
struct PositionSchemaDetailView: View {
    let schemaId: Int

    @Environment(PositionSchemaDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false
    @State private var jsonSchema: JSONSchema?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let schema = viewModel.positionSchema {
                Form {
                    // Header
                    Section {
                        schemaHeader(schema)
                    }

                    // Details
                    Section("Details") {
                        schemaDetails(schema)
                    }

                    // Schema Editor (read-only)
                    if !schema.schema.isEmpty {
                        JsonSchemaEditorView(schema: $jsonSchema, disabled: true)
                    }
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading Schema",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.positionSchema?.name ?? "Schema")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            // Refresh data after editing
            Task {
                await viewModel.refresh()
            }
        }) {
            if let schema = viewModel.positionSchema {
                NavigationStack {
                    PositionSchemaFormSheet(schema: schema)
                }
            }
        }
        .task(id: schemaId) {
            await viewModel.fetchPositionSchema(id: schemaId)
            // Set jsonSchema after fetch completes
            if let schema = viewModel.positionSchema {
                jsonSchema = Self.parseSchema(from: schema.schema)
            }
        }
        .onChange(of: viewModel.positionSchema) { _, newSchema in
            if let schema = newSchema {
                jsonSchema = Self.parseSchema(from: schema.schema)
            }
        }
    }

    /// Parse schema dictionary to JSONSchema
    private static func parseSchema(from dict: [String: RxStorageCore.AnyCodable]) -> JSONSchema? {
        let unwrappedDict = dict.mapValues { $0.value }
        guard let data = try? JSONSerialization.data(withJSONObject: unwrappedDict, options: []) else {
            return nil
        }
        return try? JSONDecoder().decode(JSONSchema.self, from: data)
    }

    // MARK: - Schema Header

    @ViewBuilder
    private func schemaHeader(_ schema: PositionSchema) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(schema.name)
                .font(.title2)
                .fontWeight(.bold)

            Text("\(schema.schema.count) fields defined")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Schema Details

    @ViewBuilder
    private func schemaDetails(_ schema: PositionSchema) -> some View {
        DetailRow(
            label: "Created",
            value: schema.createdAt.formatted(date: .abbreviated, time: .shortened),
            icon: "calendar"
        )

        DetailRow(
            label: "Updated",
            value: schema.updatedAt.formatted(date: .abbreviated, time: .shortened),
            icon: "clock"
        )
    }
}

#Preview {
    NavigationStack {
        PositionSchemaDetailView(schemaId: 1)
            .environment(PositionSchemaDetailViewModel())
    }
}
