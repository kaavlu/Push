//
//  LocationObservation.swift
//  Push
//
//  App-owned location fix. Uses Doubles only — never Core Location types.
//

import Foundation

/// Which infrastructure produced a fix.
enum LocationProviderKind: String, Codable, Sendable, Equatable {
    case coreLocation
    case simulated
    case manualTest
}

/// Single validated fix from a `LocationProviding` implementation.
/// Never shown in UI. Not a `PresenceStatus`.
/// Uses app-owned Doubles — not `CLLocation`.
struct LocationObservation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let personID: Person.ID
    let latitude: Double
    let longitude: Double
    let horizontalAccuracyMeters: Double
    let altitudeMeters: Double?
    let speedMetersPerSecond: Double?
    let courseDegrees: Double?
    /// Device clock at the GPS fix.
    let recordedAt: Date
    /// When the pipeline accepted the observation.
    let receivedAt: Date
    let provider: LocationProviderKind

    init(
        id: String = UUID().uuidString,
        personID: Person.ID,
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double,
        altitudeMeters: Double? = nil,
        speedMetersPerSecond: Double? = nil,
        courseDegrees: Double? = nil,
        recordedAt: Date,
        receivedAt: Date,
        provider: LocationProviderKind
    ) {
        self.id = id
        self.personID = personID
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.altitudeMeters = altitudeMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.courseDegrees = courseDegrees
        self.recordedAt = recordedAt
        self.receivedAt = receivedAt
        self.provider = provider
    }
}
