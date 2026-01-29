//
//  LocationFormSheet.swift
//  RxStorage
//
//  Location create/edit form
//

import SwiftUI
import MapKit
import RxStorageCore

/// Location form sheet for creating or editing locations
struct LocationFormSheet: View {
    let location: Location?
    let onCreated: ((Location) -> Void)?

    @State private var viewModel: LocationFormViewModel
    @State private var showingMapPicker = false
    @Environment(\.dismiss) private var dismiss

    init(location: Location? = nil, onCreated: ((Location) -> Void)? = nil) {
        self.location = location
        self.onCreated = onCreated
        _viewModel = State(initialValue: LocationFormViewModel(location: location))
    }

    var body: some View {
        Form {
            Section("Information") {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.words)
            }

            Section("Coordinates") {
                TextField("Latitude", text: $viewModel.latitude)
                    .keyboardType(.decimalPad)

                TextField("Longitude", text: $viewModel.longitude)
                    .keyboardType(.decimalPad)

                Button {
                    showingMapPicker = true
                } label: {
                    Label("Pick from Map", systemImage: "map")
                }
            }

            // Validation Errors
            if !viewModel.validationErrors.isEmpty {
                Section {
                    ForEach(Array(viewModel.validationErrors.keys), id: \.self) { key in
                        if let error = viewModel.validationErrors[key] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle(location == nil ? "New Location" : "Edit Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(location == nil ? "Create" : "Save") {
                    Task {
                        await submitForm()
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .sheet(isPresented: $showingMapPicker) {
            MapPickerView { coordinate in
                viewModel.updateCoordinates(coordinate)
                showingMapPicker = false
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            try await viewModel.submit()
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }
}

/// Simple map picker view
struct MapPickerView: View {
    let onSelect: (CLLocationCoordinate2D) -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, interactionModes: .all)
                .onTapGesture { location in
                    // Note: This is a simplified implementation
                    // In production, you'd want to convert screen coordinates to map coordinates
                    selectedCoordinate = region.center
                }
                .navigationTitle("Pick Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Select") {
                            if let coordinate = selectedCoordinate {
                                onSelect(coordinate)
                            } else {
                                onSelect(region.center)
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        LocationFormSheet()
    }
}
