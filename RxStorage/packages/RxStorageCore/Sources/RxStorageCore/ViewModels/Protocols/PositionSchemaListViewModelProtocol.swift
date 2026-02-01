//
//  PositionSchemaListViewModelProtocol.swift
//  RxStorageCore
//
//  Position schema list view model protocol
//

import Foundation
import Observation

/// Protocol for position schema list view model
@MainActor
public protocol PositionSchemaListViewModelProtocol: AnyObject, Observable {
    var schemas: [PositionSchema] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var searchText: String { get set }

    // Pagination properties
    var isLoadingMore: Bool { get }
    var hasNextPage: Bool { get }

    func fetchSchemas() async
    func loadMoreSchemas() async
    func refreshSchemas() async
    @discardableResult
    func deleteSchema(_ schema: PositionSchema) async throws -> Int
}
