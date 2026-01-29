//
//  PropertyListView.swift
//  JsonSchemaEditor
//

import SwiftUI

/// List of properties with add/remove/reorder
public struct PropertyListView: View {
    @Bindable var viewModel: JsonSchemaEditorViewModel
    let disabled: Bool

    public init(viewModel: JsonSchemaEditorViewModel, disabled: Bool = false) {
        self.viewModel = viewModel
        self.disabled = disabled
    }

    public var body: some View {
        VStack(spacing: 12) {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                propertyList
            }

            addButton
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Properties")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add a property to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var propertyList: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, _ in
                PropertyEditorView(
                    item: binding(for: index),
                    onDelete: { viewModel.deleteProperty(at: index) },
                    onMoveUp: index > 0 ? { viewModel.movePropertyUp(at: index) } : nil,
                    onMoveDown: index < viewModel.items.count - 1 ? { viewModel.movePropertyDown(at: index) } : nil,
                    isFirst: index == 0,
                    isLast: index == viewModel.items.count - 1,
                    disabled: disabled
                )
            }
        }
    }

    private var addButton: some View {
        Button(action: { viewModel.addProperty() }) {
            Label("Add Property", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
    }

    private func binding(for index: Int) -> Binding<PropertyItem> {
        Binding(
            get: { viewModel.items[index] },
            set: { viewModel.items[index] = $0 }
        )
    }
}
