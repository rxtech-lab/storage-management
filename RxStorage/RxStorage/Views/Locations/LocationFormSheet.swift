//
//  LocationFormSheet.swift
//  RxStorage
//
//  Location create/edit form
//

import MapKit
import RxStorageCore
import SwiftUI

/// Location form sheet for creating or editing locations
struct LocationFormSheet: View {
    let location: Location?
    let onCreated: ((Location) -> Void)?

    @State private var viewModel: LocationFormViewModel
    @State private var showingMapPicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(EventViewModel.self) private var eventViewModel

    init(location: Location? = nil, onCreated: ((Location) -> Void)? = nil) {
        self.location = location
        self.onCreated = onCreated
        _viewModel = State(initialValue: LocationFormViewModel(location: location))
    }

    var body: some View {
        Form {
            Section("Information") {
                TextField("Title", text: $viewModel.title)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
                    .accessibilityIdentifier("location-form-title-field")
            }

            Section("Coordinates") {
                TextField("Latitude", text: $viewModel.latitude)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                    .accessibilityIdentifier("location-form-latitude-field")

                TextField("Longitude", text: $viewModel.longitude)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                    .accessibilityIdentifier("location-form-longitude-field")

                Button {
                    showingMapPicker = true
                } label: {
                    Label("Pick from Map", systemImage: "map")
                }
                .accessibilityIdentifier("location-form-map-picker-button")
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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(location == nil ? "New Location" : "Edit Location")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("location-form-cancel-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(location == nil ? "Create" : "Save") {
                        Task {
                            await submitForm()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityIdentifier("location-form-submit-button")
                }
            }
        #if os(iOS)
            .fullScreenCover(isPresented: $showingMapPicker) {
                MapPickerView(
                    initialCoordinate: parseCurrentCoordinate()
                ) { coordinate in
                    viewModel.updateCoordinates(coordinate)
                    showingMapPicker = false
                }
            }
        #elseif os(macOS)
            .sheet(isPresented: $showingMapPicker) {
                MapPickerView(
                    initialCoordinate: parseCurrentCoordinate()
                ) { coordinate in
                    viewModel.updateCoordinates(coordinate)
                    showingMapPicker = false
                }
                .frame(minWidth: 600, minHeight: 500)
            }
        #endif
            .overlay {
                if viewModel.isSubmitting {
                    LoadingOverlay()
                }
            }
    }

    // MARK: - Actions

    private func submitForm() async {
        do {
            let savedLocation = try await viewModel.submit()
            // Emit event based on create vs update
            if location == nil {
                eventViewModel.emit(.locationCreated(id: savedLocation.id))
            } else {
                eventViewModel.emit(.locationUpdated(id: savedLocation.id))
            }
            // If callback provided, call with created location
            onCreated?(savedLocation)
            dismiss()
        } catch {
            // Error is already tracked in viewModel.error
        }
    }

    private func parseCurrentCoordinate() -> CLLocationCoordinate2D? {
        guard let lat = Double(viewModel.latitude),
              let lon = Double(viewModel.longitude)
        else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

#Preview {
    NavigationStack {
        LocationFormSheet()
    }
}
