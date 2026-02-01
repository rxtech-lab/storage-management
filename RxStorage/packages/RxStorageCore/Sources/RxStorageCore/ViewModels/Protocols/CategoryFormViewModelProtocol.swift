//
//  CategoryFormViewModelProtocol.swift
//  RxStorageCore
//
//  Category form view model protocol
//

import Foundation
import Observation

/// Protocol for category form view model
@MainActor
public protocol CategoryFormViewModelProtocol: AnyObject, Observable {
    var category: Category? { get }
    var name: String { get set }
    var description: String { get set }
    var isSubmitting: Bool { get }
    var error: Error? { get }
    var validationErrors: [String: String] { get }

    func validate() -> Bool
    @discardableResult
    func submit() async throws -> Category
}
