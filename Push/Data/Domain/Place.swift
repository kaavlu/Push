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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
