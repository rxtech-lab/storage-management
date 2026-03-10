//
//  LocationDetailView.swift
//  RxStorage
//
//  Location detail view with full-screen map and bottom sheet
//

import MapKit
import RxStorageCore
import SwiftUI

/// Location detail view with full-screen map and bottom sheet (iPhone) or side panel (iPad/Mac)
struct LocationDetailView: View {
    let locationId: String

    @Environment(LocationDetailViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingEditSheet = false
    @State private var showingInfoSheet = false
    @State private var showingItemsSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let location = viewModel.location {
                if horizontalSizeClass == .regular {
                    // iPad/Mac: side-by-side layout
                    regularLayout(location)
                } else {
                    // iPhone: map with bottom sheet
                    compactLayout(location)
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
            .sheet(isPresented: $showingItemsSheet) {
                EntityItemsListSheet(filter: .location(id: locationId))
            }
            .task(id: locationId) {
                await viewModel.fetchLocation(id: locationId)
            }
    }

    // MARK: - Compact Layout (iPhone)

    private func compactLayout(_ location: Location) -> some View {
        mapContent(location)
            .onAppear {
                if !showingInfoSheet {
                    showingInfoSheet = true
                }
            }
            .sheet(isPresented: $showingInfoSheet) {
                LocationInfoContent(
                    location: location,
                    items: viewModel.items,
                    totalItems: viewModel.totalItems,
                    onSeeAllItems: { showingItemsSheet = true }
                )
                .presentationDetents([.height(220), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled(true)
            }
    }

    // MARK: - Regular Layout (iPad/Mac)

    private func regularLayout(_ location: Location) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                mapContent(location)
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 16) {
                    locationInfoSection(location)
                        .cardStyle()

                    locationCoordinatesSection(location)
                        .cardStyle()

                    locationDetailsSection(location)
                        .cardStyle()

                    EntityItemsCard(
                        items: viewModel.items,
                        totalItems: viewModel.totalItems,
                        onSeeAll: { showingItemsSheet = true }
                    )
                }
                .padding()
            }
        }
        .background(Color.systemGroupedBackground)
    }

    // MARK: - Map Content

    @ViewBuilder
    private func mapContent(_ location: Location) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
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
        .ignoresSafeArea(.all)
    }

    // MARK: - Info Sections (reused in regular layout)

    private func locationInfoSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.title)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("location-detail-title")

            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func locationCoordinatesSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Coordinates", systemImage: "location")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

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
    }

    private func locationDetailsSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

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
}

// MARK: - Location Info Content (used in sheet on iPhone)

private struct LocationInfoContent: View {
    let location: Location
    let items: [StorageItem]
    let totalItems: Int
    let onSeeAllItems: () -> Void

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

                // Items section
                Section {
                    if items.isEmpty {
                        Text("No items at this location")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if totalItems > items.count {
                        Button {
                            onSeeAllItems()
                        } label: {
                            HStack {
                                Text("See All \(totalItems) Items")
                                    .foregroundStyle(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Items")
                        if totalItems > 0 {
                            Text("(\(totalItems))")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #elseif os(macOS)
            .listStyle(.inset)
            #endif
            .navigationDestination(for: StorageItem.self) { item in
                ItemDetailView(itemId: item.id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocationDetailView(locationId: "1")
            .environment(LocationDetailViewModel())
    }
}
