//
//  MapPickerView.swift
//  RxStorage
//
//  Full-screen map picker with search and user location support
//

import MapKit
import RxStorageCore
import SwiftUI
import UIKit

/// Full-screen map picker view
struct MapPickerView: View {
    let initialCoordinate: CLLocationCoordinate2D?
    let onSelect: (CLLocationCoordinate2D) -> Void

    @State private var viewModel: MapPickerViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var showSearchResults = false
    @Environment(\.dismiss) private var dismiss

    init(
        initialCoordinate: CLLocationCoordinate2D? = nil,
        onSelect: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.onSelect = onSelect
        let vm = MapPickerViewModel(initialCoordinate: initialCoordinate)
        _viewModel = State(initialValue: vm)
        _cameraPosition = State(initialValue: .region(vm.mapRegion))
    }

    var body: some View {
        NavigationStack {
            mainContent
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search location"
        )
        .onSubmit(of: .search) {
            viewModel.search(viewModel.searchText)
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .onChange(of: viewModel.searchResults.count) { _, newCount in
            showSearchResults = newCount > 0 || viewModel.isSearching
        }
        .onChange(of: viewModel.isSearching) { _, isSearching in
            if isSearching {
                showSearchResults = true
            }
        }
        .task {
            if viewModel.shouldShowLocationPermissionPrompt {
                viewModel.requestLocationPermission()
            } else if viewModel.canUseUserLocation && viewModel.userLocation == nil {
                viewModel.locateUser()
            }
        }
        .onChange(of: viewModel.mapRegion.center.latitude) { _, _ in
            cameraPosition = .region(viewModel.mapRegion)
        }
        .onChange(of: viewModel.mapRegion.center.longitude) { _, _ in
            cameraPosition = .region(viewModel.mapRegion)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            mapView
            errorOverlay
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSearchResults) {
            searchResultsSheet
        }
    }

    // MARK: - Error Overlay

    @ViewBuilder
    private var errorOverlay: some View {
        if let error = viewModel.errorMessage {
            VStack {
                Spacer()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                dismiss()
            }
        }

        ToolbarItemGroup(placement: .bottomBar) {
            locationButton
            Spacer()
            confirmButton
        }
    }

    // MARK: - Location Button

    private var locationButton: some View {
        Button {
            viewModel.selectUserLocation()
        } label: {
            HStack(spacing: 4) {
                if viewModel.isLocatingUser {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "location.fill")
                }
                Text("Current Location")
            }
        }
        .disabled(viewModel.isLocatingUser || viewModel.authorizationStatus == .denied)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            if let coordinate = viewModel.selectedCoordinate {
                onSelect(coordinate)
                dismiss()
            } else {
                print("Enable to select")
            }
        } label: {
            Text("Confirm")
                .fontWeight(.semibold)
        }
        .disabled(viewModel.selectedCoordinate == nil)
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Map View

    @ViewBuilder
    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                if let coordinate = viewModel.selectedCoordinate {
                    Marker("Selected Location", coordinate: coordinate)
                        .tint(.red)
                }
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location,
                               let coordinate = proxy.convert(location, from: .local)
                            {
                                viewModel.selectCoordinate(coordinate, centerMap: false)
                            }
                        default:
                            break
                        }
                    }
            )
            .mapStyle(.standard(elevation: .realistic))
        }
    }

    // MARK: - Search Results Sheet

    @ViewBuilder
    private var searchResultsSheet: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    ContentUnavailableView {
                        ProgressView()
                            .scaleEffect(1.5)
                    } description: {
                        Text("Searching...")
                    }
                } else if viewModel.searchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showSearchResults = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    // MARK: - Search Results List

    @ViewBuilder
    private var searchResultsList: some View {
        List(viewModel.searchResults) { result in
            Button {
                viewModel.selectSearchResult(result)
                showSearchResults = false
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    MapPickerView { coordinate in
        print("Selected: \(coordinate)")
    }
}
