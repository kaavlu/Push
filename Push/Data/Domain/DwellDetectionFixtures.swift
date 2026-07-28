//
//  DwellDetectionFixtures.swift
//  Push
//
//  Issue #99 (I1) / #100 (I2) — deterministic observation sequences for
//  dwell + arrival/departure tests.
//

import Foundation

/// Named observation sequences for dwell-detection tests.
/// Coordinates are SF-area points; labels describe intended detector outcomes.
enum DwellDetectionFixtures {
    static let defaultPersonID: Person.ID = "dwell-fixture-user"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Sequences

    /// Long stationary cluster — should promote to `.dwelling` with one arrival.
    /// 8 samples × 30s = 210s span (> minimumDwellDuration).
    static func sustainedDwellSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate,
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        idPrefix: String = "dwell"
    ) -> [LocationObservation] {
        makeSequence(
            idPrefix: idPrefix,
            personID: personID,
            baseDate: baseDate,
            count: 8,
            interval: 30,
            latitude: latitude,
            longitude: longitude,
            accuracy: 8,
            speed: 0.05,
            stepLatitudeDelta: 0.000005,
            stepLongitudeDelta: 0
        )
    }

    /// Single stationary fix — must remain non-dwelling.
    static func singleStationaryFix(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        [
            makeObservation(
                id: "single-0",
                personID: personID,
                latitude: 37.7749,
                longitude: -122.4194,
                accuracy: 8,
                recordedAt: baseDate,
                receivedAt: baseDate,
                speed: 0
            ),
        ]
    }

    /// Brief stop (~90s) — traffic-light length; must not confirm dwell.
    static func trafficLightStopSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        makeSequence(
            idPrefix: "light",
            personID: personID,
            baseDate: baseDate,
            count: 4,
            interval: 30,
            latitude: 37.7800,
            longitude: -122.4100,
            accuracy: 10,
            speed: 0.1,
            stepLatitudeDelta: 0,
            stepLongitudeDelta: 0
        )
    }

    /// Walking past a point — progressive displacement outside dwell radius.
    static func walkBySequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // ~14 m north per 10 s ≈ 1.4 m/s pedestrian; leaves radius quickly.
        makeSequence(
            idPrefix: "walkby",
            personID: personID,
            baseDate: baseDate,
            count: 8,
            interval: 10,
            latitude: 37.77490,
            longitude: -122.41940,
            accuracy: 12,
            speed: 1.4,
            stepLatitudeDelta: 0.00013,
            stepLongitudeDelta: 0
        )
    }

    /// Stationary cluster with mild GPS jitter inside the dwell radius.
    /// Centroid must stabilize; start time must not reset.
    static func gpsDriftSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // ~5–8 m jitter (well inside 40 m radius) over 4+ minutes.
        let offsets: [(Double, Double)] = [
            (0, 0),
            (0.00004, 0.00002),
            (-0.00003, 0.00005),
            (0.00005, -0.00004),
            (-0.00002, -0.00003),
            (0.00001, 0.00004),
            (-0.00004, 0.00001),
            (0.00003, -0.00002),
            (0, 0.00001),
        ]
        return offsets.enumerated().map { index, offset in
            let t = baseDate.addingTimeInterval(TimeInterval(index) * 30)
            return makeObservation(
                id: "drift-\(index)",
                personID: personID,
                latitude: 37.7699 + offset.0,
                longitude: -122.4469 + offset.1,
                accuracy: 12,
                recordedAt: t,
                receivedAt: t,
                speed: 0.08
            )
        }
    }

    /// One mid-cluster outlier blip, then return — must not reset start.
    static func blipThenReturnSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = makeSequence(
            idPrefix: "blip-base",
            personID: personID,
            baseDate: baseDate,
            count: 6,
            interval: 30,
            latitude: 37.7600,
            longitude: -122.4300,
            accuracy: 9,
            speed: 0.05,
            stepLatitudeDelta: 0,
            stepLongitudeDelta: 0
        )
        // Single far outlier between samples 3 and 4 (insert after index 3).
        let blipTime = baseDate.addingTimeInterval(3 * 30 + 15)
        let blip = makeObservation(
            id: "blip-outlier",
            personID: personID,
            latitude: 37.7600 + 0.002,
            longitude: -122.4300,
            accuracy: 15,
            recordedAt: blipTime,
            receivedAt: blipTime,
            speed: 0.1
        )
        observations.insert(blip, at: 4)
        // Extra stationary samples to ensure duration after blip.
        let tailStart = baseDate.addingTimeInterval(6 * 30)
        for index in 0..<3 {
            let t = tailStart.addingTimeInterval(TimeInterval(index) * 30)
            observations.append(
                makeObservation(
                    id: "blip-tail-\(index)",
                    personID: personID,
                    latitude: 37.7600,
                    longitude: -122.4300,
                    accuracy: 9,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 0.05
                )
            )
        }
        return observations
    }

    /// Poor accuracy samples that the detector should ignore.
    static func poorAccuracySequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        makeSequence(
            idPrefix: "poor",
            personID: personID,
            baseDate: baseDate,
            count: 6,
            interval: 30,
            latitude: 37.7500,
            longitude: -122.4000,
            accuracy: 80,
            speed: 0.05,
            stepLatitudeDelta: 0,
            stepLongitudeDelta: 0
        )
    }

    // MARK: - Builders

    private static func makeSequence(
        idPrefix: String,
        personID: Person.ID,
        baseDate: Date,
        count: Int,
        interval: TimeInterval,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        speed: Double?,
        stepLatitudeDelta: Double,
        stepLongitudeDelta: Double
    ) -> [LocationObservation] {
        (0..<count).map { index in
            let offset = TimeInterval(index) * interval
            return makeObservation(
                id: "\(idPrefix)-\(index)",
                personID: personID,
                latitude: latitude + (Double(index) * stepLatitudeDelta),
                longitude: longitude + (Double(index) * stepLongitudeDelta),
                accuracy: accuracy,
                recordedAt: baseDate.addingTimeInterval(offset),
                receivedAt: baseDate.addingTimeInterval(offset),
                speed: speed
            )
        }
    }

    static func makeObservation(
        id: String,
        personID: Person.ID,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        recordedAt: Date,
        receivedAt: Date,
        speed: Double?
    ) -> LocationObservation {
        LocationObservation(
            id: id,
            personID: personID,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: accuracy,
            altitudeMeters: nil,
            speedMetersPerSecond: speed,
            courseDegrees: nil,
            recordedAt: recordedAt,
            receivedAt: receivedAt,
            provider: .manualTest
        )
    }
}
