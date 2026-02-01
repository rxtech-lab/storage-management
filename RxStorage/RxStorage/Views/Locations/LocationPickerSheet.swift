//
//  LocationPickerSheet.swift
//  RxStorage
//
//  Searchable location picker sheet with pagination
//

import RxStorageCore
import SwiftUI

/// Searchable location picker sheet
struct LocationPickerSheet: View {
    let selectedId: Int?
    let onSelect: (Location?) -> Void

    @State private var viewModel = LocationPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search locations...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.search("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading locations...")
                Spacer()
            } else if viewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if viewModel.displayItems.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Locations" : "No Results",
                    systemImage: "mappin.circle",
                    description: Text(viewModel.searchText.isEmpty ? "Create a location first" : "No locations found")
                )
            } else {
                locationList
            }
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") {
                    onSelect(nil)
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadLocations()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
    }

    private var locationList: some View {
        List {
            ForEach(viewModel.displayItems) { location in
                Button {
                    onSelect(location)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.title)
                                .foregroundStyle(.primary)
                            if let lat = location.latitude, let lon = location.longitude {
                                Text("Lat: \(lat, specifier: "%.4f"), Lon: \(lon, specifier: "%.4f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if location.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .onAppear {
                    if viewModel.shouldLoadMore(for: location) {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
            }

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
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LocationPickerSheet(selectedId: nil) { _ in }
    }
}
