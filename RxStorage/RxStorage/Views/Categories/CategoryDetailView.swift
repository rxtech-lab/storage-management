//
//  CategoryDetailView.swift
//  RxStorage
//
//  Category detail view
//

import RxStorageCore
import SwiftUI

/// Category detail view
struct CategoryDetailView: View {
    let categoryId: String

    @Environment(CategoryDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false
    @State private var showingItemsSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let category = viewModel.category {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        categoryHeader(category)
                            .cardStyle()

                        // Details
                        categoryDetails(category)
                            .cardStyle()

                        // Items
                        EntityItemsCard(
                            items: viewModel.items,
                            totalItems: viewModel.totalItems,
                            onSeeAll: { showingItemsSheet = true }
                        )
                    }
                    .padding()
                }
                .background(Color.systemGroupedBackground)
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
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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
            .sheet(isPresented: $showingItemsSheet) {
                EntityItemsListSheet(filter: .category(id: categoryId))
            }
            .task(id: categoryId) {
                await viewModel.fetchCategory(id: categoryId)
            }
            .navigationDestination(for: StorageItem.self) { item in
                ItemDetailView(itemId: item.id)
            }
    }

    // MARK: - Category Header

    private func categoryHeader(_ category: RxStorageCore.Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("category-detail-title")

            if let description = category.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Details

    private func categoryDetails(_ category: RxStorageCore.Category) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(
                label: "Created",
                value: category.createdAt.formatted(date: .abbreviated, time: .shortened),
                icon: "calendar"
            )

            DetailRow(
                label: "Updated",
                value: category.updatedAt.formatted(date: .abbreviated, time: .shortened),
                icon: "clock"
            )
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(categoryId: "1")
            .environment(CategoryDetailViewModel())
    }
}
