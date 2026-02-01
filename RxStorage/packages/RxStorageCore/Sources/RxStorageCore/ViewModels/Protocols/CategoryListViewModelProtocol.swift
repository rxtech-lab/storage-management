//
//  CategoryListViewModelProtocol.swift
//  RxStorageCore
//
//  Category list view model protocol
//

import Foundation
import Observation

/// Protocol for category list view model
@MainActor
public protocol CategoryListViewModelProtocol: AnyObject, Observable {
    var categories: [Category] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var searchText: String { get set }

    // Pagination properties
    var isLoadingMore: Bool { get }
    var hasNextPage: Bool { get }

    func fetchCategories() async
    func loadMoreCategories() async
    func refreshCategories() async
    func deleteCategory(_ category: Category) async throws
}
