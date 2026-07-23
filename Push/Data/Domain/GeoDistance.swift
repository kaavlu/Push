//
//  GeoDistance.swift
//  Push
//
//  App-owned great-circle helpers for the location pipeline.
//  No Core Location types.
//

import Foundation

enum GeoDistance {
    /// Great-circle distance in meters between two WGS84 points (haversine).
    static func meters(
        fromLatitude lat1: Double,
        longitude lon1: Double,
        toLatitude lat2: Double,
        longitude lon2: Double
    ) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180

        let a = sin(Δφ / 2) * sin(Δφ / 2)
            + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return LocationPipelineConstants.earthRadiusMeters * c
    }

    /// Great-circle distance between two observations.
    static func meters(from: LocationObservation, to: LocationObservation) -> Double {
        meters(
            fromLatitude: from.latitude,
            longitude: from.longitude,
            toLatitude: to.latitude,
            longitude: to.longitude
        )
    }
}
