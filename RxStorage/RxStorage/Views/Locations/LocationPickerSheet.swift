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
        Group {
            if viewModel.isLoading {
                ProgressView("Loading locations...")
            } else if viewModel.isSearching {
                ProgressView("Searching...")
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
        #if os(iOS)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #endif
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
        .searchable(text: $viewModel.searchText, prompt: "Search locations")
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.search(newValue)
        }
        .task {
            await viewModel.loadLocations()
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
                            Text("Lat: \(location.latitude, specifier: "%.4f"), Lon: \(location.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
    }
}

#Preview {
    NavigationStack {
        LocationPickerSheet(selectedId: nil) { _ in }
    }
}
