//
//  PositionSchemaFormViewModelProtocol.swift
//  RxStorageCore
//
//  Position schema form view model protocol
//

import Foundation
import Observation

/// Protocol for position schema form view model
@MainActor
public protocol PositionSchemaFormViewModelProtocol: AnyObject, Observable {
    var schema: PositionSchema? { get }
    var name: String { get set }
    var schemaJSON: String { get set }
    var isSubmitting: Bool { get }
    var error: Error? { get }
    var validationErrors: [String: String] { get }

    func validate() -> Bool
    func submit() async throws
    func validateJSON() -> Bool
}
