//
//  Location.swift
//  RxStorageCore
//
//  Location model matching API schema
//

import Foundation
import CoreLocation

/// Geographic location with coordinates
public struct Location: Codable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let latitude: Double
    public let longitude: Double
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: Int,
        title: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convert to CLLocationCoordinate2D for MapKit
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Request body for creating a new location
public struct NewLocationRequest: Codable {
    public let title: String
    public let latitude: Double
    public let longitude: Double

    public init(title: String, latitude: Double, longitude: Double) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Convenience initializer from CLLocationCoordinate2D
    public init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

/// Request body for updating a location
public typealias UpdateLocationRequest = NewLocationRequest
