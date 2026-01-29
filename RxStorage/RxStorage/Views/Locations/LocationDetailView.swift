//
//  LocationDetailView.swift
//  RxStorage
//
//  Location detail view with map
//

import SwiftUI
import MapKit
import RxStorageCore

/// Location detail view
struct LocationDetailView: View {
    let locationId: Int

    @Environment(LocationDetailViewModel.self) private var viewModel
    @State private var showingEditSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let location = viewModel.location {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        locationHeader(location)

                        // Map
                        if let coordinate = location.coordinate {
                            mapSection(coordinate: coordinate, title: location.title)
                        }

                        Divider()

                        // Details
                        locationDetails(location)
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading Location",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.location?.title ?? "Location")
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
            if let location = viewModel.location {
                NavigationStack {
                    LocationFormSheet(location: location)
                }
            }
        }
        .task(id: locationId) {
            await viewModel.fetchLocation(id: locationId)
        }
    }

    // MARK: - Location Header

    @ViewBuilder
    private func locationHeader(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.title)
                .font(.title2)
                .fontWeight(.bold)

            if let lat = location.latitude, let lon = location.longitude {
                Text(String(format: "%.6f, %.6f", lat, lon))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Map Section

    @ViewBuilder
    private func mapSection(coordinate: CLLocationCoordinate2D, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Map", systemImage: "map")
                .font(.headline)

            Map {
                Marker(title, coordinate: coordinate)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Location Details

    @ViewBuilder
    private func locationDetails(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let latitude = location.latitude {
                DetailRow(
                    label: "Latitude",
                    value: String(format: "%.6f", latitude),
                    icon: "location"
                )
            }

            if let longitude = location.longitude {
                DetailRow(
                    label: "Longitude",
                    value: String(format: "%.6f", longitude),
                    icon: "location"
                )
            }

            if let createdAt = location.createdAt {
                DetailRow(
                    label: "Created",
                    value: createdAt.formatted(date: .abbreviated, time: .shortened),
                    icon: "calendar"
                )
            }

            if let updatedAt = location.updatedAt {
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
        LocationDetailView(locationId: 1)
            .environment(LocationDetailViewModel())
    }
}
