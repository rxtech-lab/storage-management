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

    func fetchSchemas() async
    func refreshSchemas() async
    func deleteSchema(_ schema: PositionSchema) async throws
}
