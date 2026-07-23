//
//  SimulatedLocationRoute.swift
//  Push
//
//  Scripted observation sequences for SimulatedLocationProvider and tests.
//  Route metadata exists only to exercise observation flow and validation —
//  no walking/driving/venue inference.
//

import Foundation

/// Ordered script of app-owned location fixes for deterministic playback.
struct SimulatedLocationRoute: Equatable, Sendable {
    /// Stable fixture label (tests / DEBUG logs).
    let name: String
    let observations: [LocationObservation]
    /// Delay before each step during timed playback. First step is usually `0`.
    /// Count must match `observations.count` (padded with `0` if shorter).
    let stepDelays: [TimeInterval]

    init(
        name: String,
        observations: [LocationObservation],
        stepDelays: [TimeInterval] = []
    ) {
        self.name = name
        self.observations = observations
        if stepDelays.count >= observations.count {
            self.stepDelays = Array(stepDelays.prefix(observations.count))
        } else {
            self.stepDelays = stepDelays + Array(
                repeating: TimeInterval(0),
                count: observations.count - stepDelays.count
            )
        }
    }

    func delayBeforeStep(at index: Int) -> TimeInterval {
        guard index >= 0, index < stepDelays.count else { return 0 }
        return stepDelays[index]
    }
}

// MARK: - Fixtures

/// Representative routes for unit tests and local dogfooding.
/// Coordinates are arbitrary SF-area points; labels describe expected validation behavior.
enum SimulatedLocationRouteFixtures {
    static let defaultPersonID: Person.ID = "sim-user"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Cluster of near-identical fixes at one point (valid stationary stream).
    static func stationary(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let coords = (latitude: 37.7749, longitude: -122.4194)
        let observations = (0..<4).map { index in
            makeObservation(
                id: "stationary-\(index)",
                personID: personID,
                latitude: coords.latitude,
                longitude: coords.longitude,
                accuracy: 8,
                recordedAt: baseDate.addingTimeInterval(TimeInterval(index * 30)),
                receivedAt: baseDate.addingTimeInterval(TimeInterval(index * 30))
            )
        }
        return SimulatedLocationRoute(
            name: "stationary",
            observations: observations,
            stepDelays: [0, 30, 30, 30]
        )
    }

    /// Plausible pedestrian spacing (~1.4 m/s along a short polyline).
    static func normalWalking(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        // ~14 m north per 10 s ≈ 1.4 m/s at SF latitude.
        let points: [(Double, Double)] = [
            (37.77490, -122.41940),
            (37.77503, -122.41940),
            (37.77516, -122.41940),
            (37.77529, -122.41940),
        ]
        let observations = points.enumerated().map { index, point in
            makeObservation(
                id: "walk-\(index)",
                personID: personID,
                latitude: point.0,
                longitude: point.1,
                accuracy: 12,
                recordedAt: baseDate.addingTimeInterval(TimeInterval(index * 10)),
                receivedAt: baseDate.addingTimeInterval(TimeInterval(index * 10)),
                speed: 1.4
            )
        }
        return SimulatedLocationRoute(
            name: "normalWalking",
            observations: observations,
            stepDelays: [0, 10, 10, 10]
        )
    }

    /// Highway-like spacing (~25 m/s) — still under max plausible speed.
    static func drivingLike(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        // ~0.00225° longitude ≈ 200 m east at SF latitude per 8 s ≈ 25 m/s.
        let points: [(Double, Double)] = [
            (37.77490, -122.41940),
            (37.77490, -122.41715),
            (37.77490, -122.41490),
            (37.77490, -122.41265),
        ]
        let observations = points.enumerated().map { index, point in
            makeObservation(
                id: "drive-\(index)",
                personID: personID,
                latitude: point.0,
                longitude: point.1,
                accuracy: 15,
                recordedAt: baseDate.addingTimeInterval(TimeInterval(index * 8)),
                receivedAt: baseDate.addingTimeInterval(TimeInterval(index * 8)),
                speed: 25
            )
        }
        return SimulatedLocationRoute(
            name: "drivingLike",
            observations: observations,
            stepDelays: [0, 8, 8, 8]
        )
    }

    /// Horizontal accuracy worse than the Phase 1 max (100 m).
    static func poorAccuracy(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let observation = makeObservation(
            id: "poor-accuracy-0",
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 500,
            recordedAt: baseDate,
            receivedAt: baseDate
        )
        return SimulatedLocationRoute(
            name: "poorAccuracy",
            observations: [observation],
            stepDelays: [0]
        )
    }

    /// `recordedAt` older than `maxObservationAge` relative to evaluation “now”.
    static func staleReadings(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let staleAt = baseDate.addingTimeInterval(
            -(LocationPipelineConstants.maxObservationAge + 120)
        )
        let observation = makeObservation(
            id: "stale-0",
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: staleAt,
            receivedAt: baseDate
        )
        return SimulatedLocationRoute(
            name: "staleReadings",
            observations: [observation],
            stepDelays: [0]
        )
    }

    /// Identical coordinates and timestamps (near-duplicate rejection).
    static func duplicates(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let first = makeObservation(
            id: "dup-0",
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 8,
            recordedAt: baseDate,
            receivedAt: baseDate
        )
        let second = makeObservation(
            id: "dup-1",
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 8,
            recordedAt: baseDate.addingTimeInterval(0.2),
            receivedAt: baseDate.addingTimeInterval(0.2)
        )
        return SimulatedLocationRoute(
            name: "duplicates",
            observations: [first, second],
            stepDelays: [0, 0.2]
        )
    }

    /// Implausible jump (multi-kilometer displacement in one second).
    static func teleportJump(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let first = makeObservation(
            id: "teleport-0",
            personID: personID,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10,
            recordedAt: baseDate,
            receivedAt: baseDate
        )
        let second = makeObservation(
            id: "teleport-1",
            personID: personID,
            latitude: 34.0522,
            longitude: -118.2437,
            accuracy: 10,
            recordedAt: baseDate.addingTimeInterval(1),
            receivedAt: baseDate.addingTimeInterval(1)
        )
        return SimulatedLocationRoute(
            name: "teleportJump",
            observations: [first, second],
            stepDelays: [0, 1]
        )
    }

    /// Large time gaps between otherwise plausible fixes.
    static func gapsBetweenObservations(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> SimulatedLocationRoute {
        let observations = [
            makeObservation(
                id: "gap-0",
                personID: personID,
                latitude: 37.7749,
                longitude: -122.4194,
                accuracy: 10,
                recordedAt: baseDate,
                receivedAt: baseDate
            ),
            makeObservation(
                id: "gap-1",
                personID: personID,
                latitude: 37.7752,
                longitude: -122.4194,
                accuracy: 10,
                recordedAt: baseDate.addingTimeInterval(120),
                receivedAt: baseDate.addingTimeInterval(120)
            ),
            makeObservation(
                id: "gap-2",
                personID: personID,
                latitude: 37.7755,
                longitude: -122.4194,
                accuracy: 10,
                recordedAt: baseDate.addingTimeInterval(300),
                receivedAt: baseDate.addingTimeInterval(300)
            ),
        ]
        return SimulatedLocationRoute(
            name: "gapsBetweenObservations",
            observations: observations,
            stepDelays: [0, 120, 180]
        )
    }

    // MARK: - Helpers

    static func makeObservation(
        id: String,
        personID: Person.ID,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        recordedAt: Date,
        receivedAt: Date,
        speed: Double? = nil,
        provider: LocationProviderKind = .simulated
    ) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: accuracy,
            speedMetersPerSecond: speed,
            recordedAt: recordedAt,
            receivedAt: receivedAt,
            provider: provider
        )
    }
}
