//
//  LocationListViewModelProtocol.swift
//  RxStorageCore
//
//  Location list view model protocol
//

import Foundation
import Observation

/// Protocol for location list view model
@MainActor
public protocol LocationListViewModelProtocol: AnyObject, Observable {
    var locations: [Location] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var searchText: String { get set }

    // Pagination properties
    var isLoadingMore: Bool { get }
    var hasNextPage: Bool { get }

    func fetchLocations() async
    func loadMoreLocations() async
    func refreshLocations() async
    func deleteLocation(_ location: Location) async throws
}
