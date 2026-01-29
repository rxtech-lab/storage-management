//
//  LocationListView.swift
//  RxStorage
//
//  Location list view
//

import SwiftUI
import RxStorageCore

/// Location list view
struct LocationListView: View {
    @State private var viewModel = LocationListViewModel()
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.locations.isEmpty {
                ProgressView("Loading locations...")
            } else if viewModel.filteredLocations.isEmpty {
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
    }

    // MARK: - Locations List

    private var locationsList: some View {
        List {
            ForEach(viewModel.filteredLocations) { location in
                LocationRow(location: location)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteLocation(location)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

/// Location row in list
struct LocationRow: View {
    let location: Location

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.title)
                .font(.headline)

            if let lat = location.latitude, let lon = location.longitude {
                Text("Lat: \(lat, specifier: "%.6f"), Lon: \(lon, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        LocationListView()
    }
}
