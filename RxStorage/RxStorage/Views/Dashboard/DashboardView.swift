//
//  DashboardView.swift
//  RxStorage
//
//  Dashboard with stats, recent items, and quick actions
//

import RxStorageCore
import SwiftUI

/// Main dashboard view
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(NavigationManager.self) private var navigationManager
    @State private var showingError = false

    // Quick action sheet states
    @State private var showingCreateItemSheet = false
    @State private var showingCreateCategorySheet = false
    @State private var showingCreateLocationSheet = false
    @State private var showingCreateAuthorSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats Cards Grid
                statsSection

                // Recent Items Section
                recentItemsSection

                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadDashboard()
        }
        .onChange(of: viewModel.error != nil) { _, hasError in
            showingError = hasError
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                viewModel.clearError()
            }
            Button("Retry") {
                Task {
                    await viewModel.loadDashboard()
                }
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingCreateItemSheet) {
            NavigationStack {
                ItemFormSheet()
            }
        }
        .sheet(isPresented: $showingCreateCategorySheet) {
            NavigationStack {
                CategoryFormSheet()
            }
        }
        .sheet(isPresented: $showingCreateLocationSheet) {
            NavigationStack {
                LocationFormSheet()
            }
        }
        .sheet(isPresented: $showingCreateAuthorSheet) {
            NavigationStack {
                AuthorFormSheet()
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            if viewModel.isLoading && viewModel.stats == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 100)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 12
                ) {
                    StatsCardView(
                        title: "Total Items",
                        value: "\(viewModel.stats?.totalItems ?? 0)",
                        subtitle:
                            "\(viewModel.stats?.publicItems ?? 0) public, \(viewModel.stats?.privateItems ?? 0) private",
                        icon: "shippingbox",
                        color: .blue
                    )

                    StatsCardView(
                        title: "Categories",
                        value: "\(viewModel.stats?.totalCategories ?? 0)",
                        subtitle: nil,
                        icon: "folder",
                        color: .green
                    )

                    StatsCardView(
                        title: "Locations",
                        value: "\(viewModel.stats?.totalLocations ?? 0)",
                        subtitle: nil,
                        icon: "mappin.circle",
                        color: .orange
                    )

                    StatsCardView(
                        title: "Authors",
                        value: "\(viewModel.stats?.totalAuthors ?? 0)",
                        subtitle: nil,
                        icon: "person.circle",
                        color: .purple
                    )
                }
            }
        }
    }

    // MARK: - Recent Items Section

    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Items")
                    .font(.headline)

                Spacer()

                Button {
                    navigationManager.navigateToItems()
                } label: {
                    Text("View All")
                        .font(.subheadline)
                }
            }

            if viewModel.isLoading && viewModel.recentItems.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 100)
            } else if viewModel.recentItems.isEmpty {
                ContentUnavailableView(
                    "No Items Yet",
                    systemImage: "shippingbox",
                    description: Text("Create your first item to get started")
                )
                .frame(height: 150)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentItems) { item in
                        RecentItemRow(item: item) {
                            Task {
                                await navigationManager.navigateToItemById(item.id)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {
                QuickActionButton(
                    title: "Add Item",
                    icon: "shippingbox.fill",
                    color: .blue
                ) {
                    showingCreateItemSheet = true
                }

                QuickActionButton(
                    title: "Add Category",
                    icon: "folder.fill.badge.plus",
                    color: .green
                ) {
                    showingCreateCategorySheet = true
                }

                QuickActionButton(
                    title: "Add Location",
                    icon: "mappin.circle.fill",
                    color: .orange
                ) {
                    showingCreateLocationSheet = true
                }

                QuickActionButton(
                    title: "Add Author",
                    icon: "person.crop.circle.fill.badge.plus",
                    color: .purple
                ) {
                    showingCreateAuthorSheet = true
                }
            }
        }
    }
}

// MARK: - Stats Card View

struct StatsCardView: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(" ")
                    .font(.caption)
                    .foregroundStyle(.clear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Recent Item Row

struct RecentItemRow: View {
    let item: DashboardRecentItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "shippingbox")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let categoryName = item.categoryName {
                            Label(categoryName, systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Visibility badge
                        if item.visibility == .publicAccess {
                            Label("Public", systemImage: "globe")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Label("Private", systemImage: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(NavigationManager())
}
