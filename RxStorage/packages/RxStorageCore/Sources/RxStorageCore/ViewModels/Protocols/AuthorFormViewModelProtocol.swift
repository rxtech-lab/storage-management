//
//  AuthorFormViewModelProtocol.swift
//  RxStorageCore
//
//  Author form view model protocol
//

import Foundation
import Observation

/// Protocol for author form view model
@MainActor
public protocol AuthorFormViewModelProtocol: AnyObject, Observable {
    var author: Author? { get }
    var name: String { get set }
    var bio: String { get set }
    var isSubmitting: Bool { get }
    var error: Error? { get }
    var validationErrors: [String: String] { get }

    func validate() -> Bool
    @discardableResult
    func submit() async throws -> Author
}
