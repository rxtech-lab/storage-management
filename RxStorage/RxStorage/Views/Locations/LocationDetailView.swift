//
//  LocationDetailView.swift
//  RxStorage
//
//  Location detail view with full-screen map and bottom sheet
//

import MapKit
import RxStorageCore
import SwiftUI

/// Sheet types for location detail view
private enum LocationSheet: Identifiable, Equatable {
    case info(Location)
    case edit(Location)

    var id: String {
        switch self {
        case .info(let location):
            return "info-\(location.id)"
        case .edit(let location):
            return "edit-\(location.id)"
        }
    }
}

/// Location detail view with full-screen map and bottom sheet for info
struct LocationDetailView: View {
    let locationId: Int

    @Environment(LocationDetailViewModel.self) private var viewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var activeSheet: LocationSheet?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let location = viewModel.location {
                fullScreenMapContent(location)
                    .onAppear {
                        // Show info sheet when location loads
                        if activeSheet == nil {
                            activeSheet = .info(location)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                activeSheet = .edit(location)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .info(let location):
                LocationInfoSheet(location: location)
                    .presentationDetents([.height(180), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .interactiveDismissDisabled(true)

            case .edit(let location):
                NavigationStack {
                    LocationFormSheet(location: location)
                }
            }
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            // When edit sheet is dismissed, show info sheet again
            if case .edit = oldValue, newValue == nil {
                if let location = viewModel.location {
                    activeSheet = .info(location)
                }
            }
        }
        .task(id: locationId) {
            await viewModel.fetchLocation(id: locationId)
        }
    }

    // MARK: - Full Screen Map Content

    @ViewBuilder
    private func fullScreenMapContent(_ location: Location) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        ZStack {
            Map(position: $cameraPosition) {
                Marker(location.title, coordinate: coordinate)
                    .tint(.red)
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .mapStyle(.standard(elevation: .realistic))
            .onAppear {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: - Location Info Sheet

private struct LocationInfoSheet: View {
    let location: Location

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(location.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Coordinates section
                Section("Coordinates") {
                    LabeledContent {
                        Text(String(format: "%.6f", location.latitude))
                    } label: {
                        Label("Latitude", systemImage: "location")
                    }

                    LabeledContent {
                        Text(String(format: "%.6f", location.longitude))
                    } label: {
                        Label("Longitude", systemImage: "location")
                    }
                }

                // Metadata section
                Section("Details") {
                    LabeledContent {
                        Text(location.createdAt.formatted(date: .abbreviated, time: .shortened))
                    } label: {
                        Label("Created", systemImage: "calendar")
                    }

                    LabeledContent {
                        Text(location.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    } label: {
                        Label("Updated", systemImage: "clock")
                    }
                }
            }
            #if os(iOS)
.listStyle(.insetGrouped)
#elseif os(macOS)
.listStyle(.inset)
#endif
        }
    }
}

#Preview {
    NavigationStack {
        LocationDetailView(locationId: 1)
            .environment(LocationDetailViewModel())
    }
}
