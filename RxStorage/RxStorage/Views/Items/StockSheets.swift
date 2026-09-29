//
//  StockSheets.swift
//  RxStorage
//
//  Stock management sheets for ItemDetailView
//

import RxStorageCore
import SwiftUI

// MARK: - Stock Move Helpers

/// Placement a move starts from (nil stock ID = the item's main placement)
private struct StockMoveOrigin: Identifiable {
    let id = UUID()
    let stockId: String?
}

/// A move whose destination has been picked
private struct PendingStockMove: Identifiable {
    let id = UUID()
    let stockId: String?
    let destinationParentId: String?
    let destinationTitle: String?
}

// MARK: - Stock Detail Sheet

struct StockDetailSheet: View {
    let viewModel: ItemDetailViewModel
    let errorViewModel: ErrorViewModel
    let isViewOnly: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(EventViewModel.self) private var eventViewModel
    @State private var showingAddSheet = false
    @State private var selectedStockForEdit: ItemStock?
    @State private var showingMainPlacementEdit = false
    @State private var pickingDestinationFor: StockMoveOrigin?
    @State private var stagedMove: PendingStockMove?
    @State private var activeMove: PendingStockMove?
    @State private var stockToReturn: ItemStock?
    @State private var showReturnConfirmation = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Current Quantity", systemImage: "shippingbox")
                    Spacer()
                    Text("\(viewModel.quantity)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            placementsSection

            Section("History") {
                if viewModel.stockHistory.isEmpty {
                    Text("No stock history yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.stockHistory) { entry in
                        HStack {
                            Text(entry.quantity > 0 ? "+\(entry.quantity)" : "\(entry.quantity)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundStyle(entry.quantity > 0 ? .green : .red)
                                .frame(width: 60, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                if let note = entry.note {
                                    Text(note)
                                        .font(.subheadline)
                                }
                                Text(entry.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        guard !isViewOnly else { return }
                        for index in indexSet {
                            let entry = viewModel.stockHistory[index]
                            Task { await deleteStockEntry(entry.id) }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        .frame(minWidth: 400, minHeight: 300)
        #endif
        .navigationTitle("Stock")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !isViewOnly {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    StockEntrySheet(viewModel: viewModel, errorViewModel: errorViewModel)
                }
            }
            .sheet(item: $selectedStockForEdit) { stock in
                NavigationStack {
                    ItemStockFormSheet(stock: stock) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .sheet(isPresented: $showingMainPlacementEdit) {
                if let item = viewModel.item {
                    NavigationStack {
                        ItemFormSheet(item: item.toStorageItem())
                    }
                }
            }
            .sheet(item: $pickingDestinationFor, onDismiss: {
                // Present the move once the picker is gone
                activeMove = stagedMove
                stagedMove = nil
            }) { origin in
                NavigationStack {
                    ParentItemPickerSheet(selectedId: nil, excludeItemId: viewModel.item?.id) { parent in
                        stagedMove = PendingStockMove(
                            stockId: origin.stockId,
                            destinationParentId: parent?.id,
                            destinationTitle: parent?.title
                        )
                    }
                }
            }
            .sheet(item: $activeMove) { move in
                if let item = viewModel.item {
                    NavigationStack {
                        MoveStockSheet(
                            itemId: item.id,
                            itemTitle: item.title,
                            destinationParentId: move.destinationParentId,
                            destinationTitle: move.destinationTitle,
                            preselectedStockId: move.stockId
                        ) { result in
                            emitMoveEvents(result)
                        }
                    }
                }
            }
            .confirmationDialog(
                title: "Return to Main Placement",
                message: "Move the \(stockToReturn?.quantity ?? 0) units in \"\(stockToReturn?.parent?.value1.title ?? "No parent")\" back to the main placement? Its location, positions, and images will be removed.",
                confirmButtonTitle: "Return",
                isPresented: $showReturnConfirmation,
                onConfirm: {
                    guard let stock = stockToReturn else { return }
                    stockToReturn = nil
                    Task { await returnToMain(stock) }
                },
                onCancel: { stockToReturn = nil }
            )
    }

    // MARK: - Placements

    @ViewBuilder
    private var placementsSection: some View {
        if let item = viewModel.item {
            Section {
                Button {
                    if !isViewOnly {
                        showingMainPlacementEdit = true
                    }
                } label: {
                    placementRow(
                        title: item.parent?.value1.title ?? "No parent",
                        subtitle: mainPlacementSubtitle(item),
                        badge: "Main",
                        quantity: viewModel.mainQuantity,
                        imageURL: item.images.first?.url
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stock-main-placement-row")
                .contextMenu {
                    if !isViewOnly {
                        mainPlacementActions
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !isViewOnly {
                        mainPlacementActions
                    }
                }

                ForEach(viewModel.stocks) { stock in
                    Button {
                        if !isViewOnly {
                            selectedStockForEdit = stock
                        }
                    } label: {
                        placementRow(
                            title: stock.parent?.value1.title ?? "No parent",
                            subtitle: placementSubtitle(stock),
                            badge: nil,
                            quantity: stock.quantity,
                            imageURL: stock.images.first?.url
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stock-placement-row")
                    .contextMenu {
                        if !isViewOnly {
                            placementActions(stock)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !isViewOnly {
                            placementActions(stock)
                        }
                    }
                }
            } header: {
                Text("Placements")
            } footer: {
                if !isViewOnly {
                    Text("Swipe a placement to move units to another parent. Tap one to edit its location, positions, and images. The main placement uses the item's own properties.")
                }
            }
        }
    }

    @ViewBuilder
    private var mainPlacementActions: some View {
        Button {
            pickingDestinationFor = StockMoveOrigin(stockId: nil)
        } label: {
            Label("Move…", systemImage: "arrow.right.square")
        }
        .tint(.blue)
        Button {
            showingMainPlacementEdit = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.orange)
    }

    private func mainPlacementSubtitle(_ item: StorageItemDetail) -> String? {
        var parts: [String] = []
        if let location = item.location?.value1.title {
            parts.append(location)
        }
        if !item.positions.isEmpty {
            parts.append(item.positions.count == 1 ? "1 position" : "\(item.positions.count) positions")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func placementActions(_ stock: ItemStock) -> some View {
        Button {
            pickingDestinationFor = StockMoveOrigin(stockId: stock.id)
        } label: {
            Label("Move…", systemImage: "arrow.right.square")
        }
        .tint(.blue)
        Button {
            selectedStockForEdit = stock
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.orange)
        Button(role: .destructive) {
            stockToReturn = stock
            showReturnConfirmation = true
        } label: {
            Label("Return to Main", systemImage: "arrow.uturn.backward")
        }
    }

    private func placementSubtitle(_ stock: ItemStock) -> String? {
        var parts: [String] = []
        if let location = stock.location?.value1.title {
            parts.append(location)
        }
        if !stock.positions.isEmpty {
            parts.append(stock.positions.count == 1 ? "1 position" : "\(stock.positions.count) positions")
        }
        if let note = stock.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func placementRow(
        title: String,
        subtitle: String?,
        badge: String?,
        quantity: Int,
        imageURL: String?
    ) -> some View {
        HStack(spacing: 12) {
            Group {
                if let imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color.systemGray6
                        }
                    }
                } else {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("×\(quantity)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func emitMoveEvents(_ result: MoveStockResult) {
        if let source = result.sourceParentId, source != result.destinationParentId {
            eventViewModel.emit(.childRemoved(parentId: source, childId: result.itemId))
        }
        if let destination = result.destinationParentId {
            eventViewModel.emit(.childAdded(parentId: destination, childId: result.itemId))
        }
        eventViewModel.emit(.itemUpdated(id: result.itemId))
    }

    private func returnToMain(_ stock: ItemStock) async {
        do {
            try await viewModel.returnStockToMain(stockId: stock.id)
            if let parentId = stock.parentId {
                eventViewModel.emit(.childRemoved(parentId: parentId, childId: stock.itemId))
            }
        } catch {
            errorViewModel.showError(error)
        }
    }

    private func deleteStockEntry(_ id: String) async {
        do {
            try await viewModel.deleteStockEntry(id: id)
        } catch {
            errorViewModel.showError(error)
        }
    }
}

// MARK: - Stock Entry Sheet

struct StockEntrySheet: View {
    let viewModel: ItemDetailViewModel
    let errorViewModel: ErrorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var quantityText = ""
    @State private var note = ""
    @State private var selectedStockId: String?
    @State private var isSubmitting = false

    var body: some View {
        Form {
            if !viewModel.stocks.isEmpty {
                Section("Placement") {
                    Picker("Placement", selection: $selectedStockId) {
                        Text("Main (\(viewModel.item?.parent?.value1.title ?? "No parent"))")
                            .tag(String?.none)
                        ForEach(viewModel.stocks) { stock in
                            Text("\(stock.parent?.value1.title ?? "No parent") (×\(stock.quantity))")
                                .tag(Optional(stock.id))
                        }
                    }
                }
            }
            Section {
                TextField("Quantity", text: $quantityText)
                #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                #endif
                TextField("Note (optional)", text: $note)
            } footer: {
                Text("Use positive numbers to add stock, negative to remove.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Add Stock Entry")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || Int(quantityText) == nil || Int(quantityText) == 0)
                }
            }
    }

    private func submit() async {
        guard let qty = Int(quantityText), qty != 0 else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await viewModel.addStockEntry(
                quantity: qty,
                note: note.isEmpty ? nil : note,
                stockId: selectedStockId
            )
            dismiss()
        } catch {
            errorViewModel.showError(error)
        }
    }
}
