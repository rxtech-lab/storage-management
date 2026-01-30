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
        Group {
            if viewModel.items.isEmpty {
                Section {
                    Text("No properties. Add a property to get started.")
                }
            } else {
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

            Section {
                Button("Add Property") {
                    viewModel.addProperty()
                }
                .disabled(disabled)
            }
        }
    }

    private func binding(for index: Int) -> Binding<PropertyItem> {
        Binding(
            get: { viewModel.items[index] },
            set: { viewModel.items[index] = $0 }
        )
    }
}
