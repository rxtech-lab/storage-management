//
//  LocationListView.swift
//  RxStorage
//
//  Location list view
//

import RxStorageCore
import SwiftUI

/// Location list view
struct LocationListView: View {
    @Binding var selectedLocation: Location?
    let horizontalSizeClass: UserInterfaceSizeClass

    @State private var viewModel = LocationListViewModel()
    @State private var showingCreateSheet = false
    @State private var isRefreshing = false
    @State private var errorViewModel = ErrorViewModel()
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var locationToDelete: Location?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedLocation: Binding<Location?> = .constant(nil)) {
        self.horizontalSizeClass = horizontalSizeClass
        _selectedLocation = selectedLocation
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.locations.isEmpty {
                ProgressView("Loading locations...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
            } else if viewModel.locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "mappin.circle",
                    description: Text(viewModel.searchText.isEmpty ? "Create your first location" : "No results found")
                )
            } else {
                locationsList
            }
        }
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Location", systemImage: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search locations")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .refreshable {
            await viewModel.refreshLocations()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                LocationFormSheet()
            }
        }
        .task {
            await viewModel.fetchLocations()
        }
        .task {
            // Listen for location events and refresh
            for await event in eventViewModel.stream {
                switch event {
                case .locationCreated, .locationUpdated, .locationDeleted:
                    isRefreshing = true
                    await viewModel.refreshLocations()
                    isRefreshing = false
                default:
                    break
                }
            }
        }
        .overlay {
            if isRefreshing {
                LoadingOverlay(title: "Refreshing...")
            }
        }
        .confirmationDialog(
            title: "Delete Location",
            message: "Are you sure you want to delete \"\(locationToDelete?.title ?? "")\"? This action cannot be undone.",
            confirmButtonTitle: "Delete",
            isPresented: $showDeleteConfirmation,
            onConfirm: {
                if let location = locationToDelete {
                    Task {
                        do {
                            let deletedId = try await viewModel.deleteLocation(location)
                            eventViewModel.emit(.locationDeleted(id: deletedId))
                        } catch {
                            errorViewModel.showError(error)
                        }
                        locationToDelete = nil
                    }
                }
            },
            onCancel: { locationToDelete = nil }
        )
        .onChange(of: viewModel.error != nil) { _, hasError in
            if hasError, let error = viewModel.error {
                errorViewModel.showError(error)
            }
        }
        .showViewModelError(errorViewModel)
    }

    // MARK: - Locations List

    private var locationsList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedLocation) {
            ForEach(viewModel.locations) { location in
                NavigationLink(value: location) {
                    LocationRow(location: location)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        locationToDelete = location
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if shouldLoadMore(for: location) {
                        Task {
                            await viewModel.loadMoreLocations()
                        }
                    }
                }
            }

            // Loading more indicator
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
    }

    // MARK: - Pagination Helper

    private func shouldLoadMore(for location: Location) -> Bool {
        guard let index = viewModel.locations.firstIndex(where: { $0.id == location.id }) else {
            return false
        }
        let threshold = 3
        return index >= viewModel.locations.count - threshold &&
            viewModel.hasNextPage &&
            !viewModel.isLoadingMore &&
            !viewModel.isLoading
    }
}

/// Location row in list
struct LocationRow: View {
    let location: Location

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.title)
                .font(.headline)

            Text("Lat: \(location.latitude, specifier: "%.6f"), Lon: \(location.longitude, specifier: "%.6f")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var selectedLocation: Location?
    NavigationStack {
        LocationListView(horizontalSizeClass: .compact, selectedLocation: $selectedLocation)
    }
}
