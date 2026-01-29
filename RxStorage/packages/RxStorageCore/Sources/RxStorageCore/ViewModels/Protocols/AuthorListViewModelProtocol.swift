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

    func fetchAuthors() async
    func refreshAuthors() async
    func deleteAuthor(_ author: Author) async throws
}
