//
//  StockSheets.swift
//  RxStorage
//
//  Stock management sheets for ItemDetailView
//

import RxStorageCore
import SwiftUI

// MARK: - Stock Detail Sheet

struct StockDetailSheet: View {
    let viewModel: ItemDetailViewModel
    let errorViewModel: ErrorViewModel
    let isViewOnly: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false

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
    @State private var isSubmitting = false

    var body: some View {
        Form {
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
                note: note.isEmpty ? nil : note
            )
            dismiss()
        } catch {
            errorViewModel.showError(error)
        }
    }
}
