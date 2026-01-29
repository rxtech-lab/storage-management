//
//  CategoryDetailView.swift
//  RxStorage
//
//  Category detail view
//

import SwiftUI
import RxStorageCore

/// Category detail view
struct CategoryDetailView: View {
    let categoryId: Int

    @Environment(CategoryDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let category = viewModel.category {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        categoryHeader(category)

                        Divider()

                        // Details
                        categoryDetails(category)
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading Category",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.category?.name ?? "Category")
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
        .sheet(isPresented: $showingEditSheet) {
            if let category = viewModel.category {
                NavigationStack {
                    CategoryFormSheet(category: category)
                }
            }
        }
        .task(id: categoryId) {
            await viewModel.fetchCategory(id: categoryId)
        }
    }

    // MARK: - Category Header

    @ViewBuilder
    private func categoryHeader(_ category: RxStorageCore.Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.title2)
                .fontWeight(.bold)

            if let description = category.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Category Details

    @ViewBuilder
    private func categoryDetails(_ category: RxStorageCore.Category) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let createdAt = category.createdAt {
                DetailRow(
                    label: "Created",
                    value: createdAt.formatted(date: .abbreviated, time: .shortened),
                    icon: "calendar"
                )
            }

            if let updatedAt = category.updatedAt {
                DetailRow(
                    label: "Updated",
                    value: updatedAt.formatted(date: .abbreviated, time: .shortened),
                    icon: "clock"
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(categoryId: 1)
            .environment(CategoryDetailViewModel())
    }
}
