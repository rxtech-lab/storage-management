//
//  AuthorListViewModelProtocol.swift
//  RxStorageCore
//
//  Author list view model protocol
//

import Foundation
import Observation

/// Protocol for author list view model
@MainActor
public protocol AuthorListViewModelProtocol: AnyObject, Observable {
    var authors: [Author] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var searchText: String { get set }

    // Pagination properties
    var isLoadingMore: Bool { get }
    var hasNextPage: Bool { get }

    func fetchAuthors() async
    func loadMoreAuthors() async
    func refreshAuthors() async
    @discardableResult
    func deleteAuthor(_ author: Author) async throws -> Int
}
