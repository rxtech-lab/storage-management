//
//  LocationFormViewModelProtocol.swift
//  RxStorageCore
//
//  Location form view model protocol
//

import CoreLocation
import Foundation
import Observation

/// Protocol for location form view model
@MainActor
public protocol LocationFormViewModelProtocol: AnyObject, Observable {
    var location: Location? { get }
    var title: String { get set }
    var latitude: String { get set }
    var longitude: String { get set }
    var isSubmitting: Bool { get }
    var error: Error? { get }
    var validationErrors: [String: String] { get }

    func validate() -> Bool
    @discardableResult
    func submit() async throws -> Location
    func updateCoordinates(_ coordinate: CLLocationCoordinate2D)
}
