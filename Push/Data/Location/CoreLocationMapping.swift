//
//  CoreLocationMapping.swift
//  Push
//
//  Pure CLLocation / CLAuthorizationStatus → app-owned types.
//  Core Location imports stay in this infrastructure folder only.
//

import CoreLocation
import Foundation

/// Accuracy / filter defaults for foreground when-in-use collection.
/// Tuned for the 50 m movement gate without over-sampling battery.
enum CoreLocationProviderConstants {
    /// ~tens of meters — enough fidelity for the 50 m displacement threshold.
    static let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters
    /// Deliver when the device moves this far (meters). Below session throttle so
    /// candidates reach the pipeline; session still enforces 60 s / 50 m upload.
    static let distanceFilterMeters: CLLocationDistance = 25
    static let activityType: CLActivityType = .other
}

/// Maps Apple location types into domain values. No manager side effects.
enum CoreLocationMapping {
    static func authorizationState(
        from status: CLAuthorizationStatus
    ) -> LocationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .whenInUse
        case .authorizedAlways:
            return .always
        @unknown default:
            return .denied
        }
    }

    /// Maps a Core Location fix into an app-owned observation.
    /// Invalid Apple sentinel values are normalized so the validator can reject safely.
    static func observation(
        from location: CLLocation,
        personID: Person.ID,
        receivedAt: Date = Date(),
        id: String = UUID().uuidString
    ) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: finiteOrZero(location.coordinate.latitude),
            longitude: finiteOrZero(location.coordinate.longitude),
            horizontalAccuracyMeters: normalizedHorizontalAccuracy(location.horizontalAccuracy),
            altitudeMeters: normalizedAltitude(
                altitude: location.altitude,
                verticalAccuracy: location.verticalAccuracy
            ),
            speedMetersPerSecond: normalizedSpeed(location.speed),
            courseDegrees: normalizedCourse(location.course),
            recordedAt: location.timestamp,
            receivedAt: receivedAt,
            provider: .coreLocation
        )
    }

    // MARK: - Normalization

    /// Negative / non-finite horizontal accuracy → 0 so validator rejects (`accuracy > 0`).
    static func normalizedHorizontalAccuracy(_ accuracy: CLLocationAccuracy) -> Double {
        guard accuracy.isFinite, accuracy > 0 else { return 0 }
        return accuracy
    }

    /// Invalid altitude when vertical accuracy is negative or non-finite.
    static func normalizedAltitude(
        altitude: CLLocationDistance,
        verticalAccuracy: CLLocationAccuracy
    ) -> Double? {
        guard verticalAccuracy.isFinite, verticalAccuracy >= 0, altitude.isFinite else {
            return nil
        }
        return altitude
    }

    /// Apple uses negative speed as "invalid".
    static func normalizedSpeed(_ speed: CLLocationSpeed) -> Double? {
        guard speed.isFinite, speed >= 0 else { return nil }
        return speed
    }

    /// Apple uses negative course as "invalid".
    static func normalizedCourse(_ course: CLLocationDirection) -> Double? {
        guard course.isFinite, course >= 0 else { return nil }
        return course
    }

    private static func finiteOrZero(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }
}
