//
//  Place.swift
//  Push
//

import CoreLocation
import Foundation

struct Place: Identifiable, Codable, Equatable {
    let id: String
    /// Full venue name, e.g. "Crunch Fitness".
    let name: String
    /// Compact name used on pucks, e.g. "Crunch".
    let shortName: String
    /// Street-level label, e.g. "350 Bay St".
    let address: String
    /// Neighborhood-level label used when location visibility is `vague`.
    let vagueLabel: String
    let latitude: Double
    let longitude: Double
    let vagueLatitude: Double?
    let vagueLongitude: Double?

    init(
        id: String,
        name: String,
        shortName: String,
        address: String,
        vagueLabel: String,
        latitude: Double,
        longitude: Double,
        vagueLatitude: Double? = nil,
        vagueLongitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.address = address
        self.vagueLabel = vagueLabel
        self.latitude = latitude
        self.longitude = longitude
        self.vagueLatitude = vagueLatitude
        self.vagueLongitude = vagueLongitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var vagueCoordinate: CLLocationCoordinate2D? {
        guard let vagueLatitude, let vagueLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: vagueLatitude, longitude: vagueLongitude)
    }
}
