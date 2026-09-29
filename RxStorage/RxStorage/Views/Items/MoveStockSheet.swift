//
//  MoveStockSheet.swift
//  RxStorage
//
//  Sheet for moving some or all units of an item into another parent
//

import RxStorageCore
import SwiftUI

/// Outcome of a move, used to notify parents that gained or lost the item
struct MoveStockResult: Sendable {
    let itemId: String
    let sourceParentId: String?
    let destinationParentId: String?
}

/// Shows where an item moves from and to, and how many units to move
struct MoveStockSheet: View {
    let itemTitle: String
    let onMoved: (MoveStockResult) -> Void

    @State private var viewModel: MoveStockViewModel
    @State private var errorViewModel = ErrorViewModel()
    @Environment(\.dismiss) private var dismiss

    init(
        itemId: String,
        itemTitle: String,
        destinationParentId: String?,
        destinationTitle: String?,
        preselectedStockId: String? = nil,
        onMoved: @escaping (MoveStockResult) -> Void
    ) {
        self.itemTitle = itemTitle
        self.onMoved = onMoved
        _viewModel = State(initialValue: MoveStockViewModel(
            itemId: itemId,
            destinationParentId: destinationParentId,
            destinationTitle: destinationTitle,
            preselectedStockId: preselectedStockId
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.item == nil {
                ProgressView("Loading...")
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Unable to Load Item",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                form
            }
        }
        .navigationTitle("Move \(itemTitle)")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        Task { await submit() }
                    }
                    .disabled(!viewModel.canSubmit)
                    .accessibilityIdentifier("move-stock-confirm-button")
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    LoadingOverlay(title: "Moving...")
                }
            }
            .task {
                await viewModel.load()
            }
            .showViewModelError(errorViewModel)
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    // MARK: - Form

    private var form: some View {
        Form {
            Section {
                routeRow
            }

            if viewModel.sources.count > 1 {
                Section("Move From") {
                    Picker("Move From", selection: $viewModel.selectedSourceId) {
                        ForEach(viewModel.sources) { source in
                            sourceLabel(source)
                                .tag(Optional(source.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }

            amountSection

            if viewModel.canKeepSeparate {
                Section {
                    Toggle("Keep as Separate Placement", isOn: $viewModel.keepSeparate)
                        .accessibilityIdentifier("move-stock-keep-separate-toggle")
                } footer: {
                    Text("Separate placements can have their own location, positions, and images.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var routeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            endpoint(
                label: "From",
                title: viewModel.selectedSource?.displayName ?? "—",
                subtitle: viewModel.selectedSource?.locationTitle
            )
            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            endpoint(label: "To", title: viewModel.destinationDisplayName, subtitle: nil)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("move-stock-route")
    }

    private func endpoint(label: String, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(title, systemImage: "shippingbox")
                .font(.headline)
                .lineLimit(2)
            if let subtitle {
                Label(subtitle, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceLabel(_ source: StockSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                if let location = source.locationTitle {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("×\(source.quantity)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        Section {
            if viewModel.canChooseAmount {
                Stepper(value: $viewModel.quantity, in: 1 ... viewModel.maxQuantity) {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        Text("\(viewModel.quantity) of \(viewModel.maxQuantity)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .accessibilityIdentifier("move-stock-quantity-stepper")

                Button("Move All (\(viewModel.maxQuantity))") {
                    viewModel.quantity = viewModel.maxQuantity
                }
                .disabled(viewModel.isMovingAll)
            } else {
                HStack {
                    Text("Quantity")
                    Spacer()
                    Text(viewModel.selectedSource?.quantity == 1 ? "1" : "Entire item")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Amount")
        } footer: {
            amountFooter
        }
    }

    private var amountFooter: Text {
        if viewModel.isSourceInDestination && !viewModel.keepSeparate {
            return Text("Already in \(viewModel.destinationDisplayName).")
        }
        var parts: [String] = []
        if let source = viewModel.selectedSource, viewModel.remainingQuantity > 0 {
            parts.append("\(viewModel.remainingQuantity) will stay in \(source.displayName).")
        }
        if let target = viewModel.mergeTarget {
            parts.append("Combined with the \(target.quantity) already in \(viewModel.destinationDisplayName).")
        }
        return Text(parts.joined(separator: " "))
    }

    // MARK: - Actions

    private func submit() async {
        let sourceParentId = viewModel.selectedSource?.parentId
        do {
            try await viewModel.submit()
            onMoved(MoveStockResult(
                itemId: viewModel.itemId,
                sourceParentId: sourceParentId,
                destinationParentId: viewModel.destinationParentId
            ))
            dismiss()
        } catch {
            errorViewModel.showError(error)
        }
    }
}

#Preview {
    NavigationStack {
        MoveStockSheet(
            itemId: "1",
            itemTitle: "Screws",
            destinationParentId: "2",
            destinationTitle: "Box B",
            onMoved: { _ in }
        )
    }
}
