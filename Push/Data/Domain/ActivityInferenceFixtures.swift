//
//  ActivityInferenceFixtures.swift
//  Push
//
//  Issue #92 (I1) — observation-window helpers and deterministic sequences
//  for activity-inference unit tests (rules land in Issue #93).
//

import Foundation

// MARK: - Observation window

/// Pure helpers for trimming / ordering observation windows for inference.
enum ActivityObservationWindow {
    /// Observations with `recordedAt` within `maxAge` of `evaluationTime`,
    /// sorted ascending by `recordedAt`. Drops non-finite coordinates.
    static func recent(
        from observations: [LocationObservation],
        at evaluationTime: Date,
        maxAge: TimeInterval = ActivityInferenceConfiguration.maxObservationWindowAge
    ) -> [LocationObservation] {
        let earliest = evaluationTime.addingTimeInterval(-maxAge)
        return observations
            .filter { observation in
                guard observation.latitude.isFinite, observation.longitude.isFinite else {
                    return false
                }
                return observation.recordedAt >= earliest
                    && observation.recordedAt <= evaluationTime
                        .addingTimeInterval(LocationPipelineConstants.futureTimestampTolerance)
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Wall-clock span from first to last observation, or `0` when fewer than 2.
    static func duration(_ observations: [LocationObservation]) -> TimeInterval {
        guard let first = observations.first, let last = observations.last else {
            return 0
        }
        return max(0, last.recordedAt.timeIntervalSince(first.recordedAt))
    }

    /// Great-circle displacement from first to last observation (meters).
    static func netDisplacementMeters(_ observations: [LocationObservation]) -> Double {
        guard let first = observations.first, let last = observations.last else {
            return 0
        }
        return GeoDistance.meters(from: first, to: last)
    }

    /// Mean of finite `speedMetersPerSecond` samples, ignoring spikes above threshold.
    static func meanSpeedMetersPerSecond(
        _ observations: [LocationObservation],
        spikeThreshold: Double = ActivityInferenceConfiguration
            .speedSpikeIgnoreThresholdMetersPerSecond
    ) -> Double? {
        let speeds = observations.compactMap { observation -> Double? in
            guard let speed = observation.speedMetersPerSecond, speed.isFinite else {
                return nil
            }
            if speed > spikeThreshold { return nil }
            if speed < 0 { return nil }
            return speed
        }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// Mean horizontal accuracy of finite samples.
    static func meanHorizontalAccuracyMeters(
        _ observations: [LocationObservation]
    ) -> Double? {
        let values = observations
            .map(\.horizontalAccuracyMeters)
            .filter { $0.isFinite && $0 > 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Deterministic sequences

/// Named observation sequences for activity-inference tests.
/// Coordinates are SF-area points; labels describe intended I2 classification,
/// not current engine output (I1 always returns `.unknown`).
enum ActivityInferenceFixtures {
    static let defaultPersonID: Person.ID = "activity-fixture-user"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Public sequences

    /// Near-identical fixes at one point (stationary / chill candidate).
    static func stationarySequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate,
        count: Int = 6,
        interval: TimeInterval = 30
    ) -> [LocationObservation] {
        makeSequence(
            idPrefix: "stationary",
            personID: personID,
            baseDate: baseDate,
            count: count,
            interval: interval,
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 8,
            speed: 0.05,
            stepLatitudeDelta: 0,
            stepLongitudeDelta: 0
        )
    }

    /// Sustained low-movement dwell long enough for future `chilling` rules.
    static func chillingSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // 10 samples × 60s = 9 minutes dwell (> chillingMinimumDuration).
        makeSequence(
            idPrefix: "chilling",
            personID: personID,
            baseDate: baseDate,
            count: 10,
            interval: 60,
            latitude: 37.7699,
            longitude: -122.4469,
            accuracy: 10,
            speed: 0.1,
            stepLatitudeDelta: 0.00001,
            stepLongitudeDelta: 0
        )
    }

    /// Pedestrian spacing ≈ 1.4 m/s north along a short line.
    static func walkingSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // ~14 m north per 10 s ≈ 1.4 m/s at SF latitude.
        makeSequence(
            idPrefix: "walking",
            personID: personID,
            baseDate: baseDate,
            count: 6,
            interval: 10,
            latitude: 37.77490,
            longitude: -122.41940,
            accuracy: 12,
            speed: 1.4,
            stepLatitudeDelta: 0.00013,
            stepLongitudeDelta: 0
        )
    }

    /// Highway-scale motion ≈ 20 m/s along longitude.
    static func drivingSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // ~200 m east per 10 s ≈ 20 m/s.
        makeSequence(
            idPrefix: "driving",
            personID: personID,
            baseDate: baseDate,
            count: 6,
            interval: 10,
            latitude: 37.78000,
            longitude: -122.42000,
            accuracy: 15,
            speed: 20,
            stepLatitudeDelta: 0,
            stepLongitudeDelta: 0.0023
        )
    }

    /// Ambiguous moderate motion (bike / jog / noisy mid-speed).
    static func genericMovingSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        // ~3.2 m/s — above walking band, below driving floor.
        makeSequence(
            idPrefix: "moving",
            personID: personID,
            baseDate: baseDate,
            count: 5,
            interval: 10,
            latitude: 37.77000,
            longitude: -122.41000,
            accuracy: 18,
            speed: 3.2,
            stepLatitudeDelta: 0.00029,
            stepLongitudeDelta: 0
        )
    }

    /// One sample with an impossible speed spike; others stationary.
    static func noisySpeedSpikeSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = stationarySequence(
            personID: personID,
            baseDate: baseDate,
            count: 5,
            interval: 20
        )
        guard observations.count > 2 else { return observations }
        let spikeIndex = 2
        let base = observations[spikeIndex]
        observations[spikeIndex] = LocationObservation(
            id: base.id,
            personID: base.personID,
            latitude: base.latitude,
            longitude: base.longitude,
            horizontalAccuracyMeters: base.horizontalAccuracyMeters,
            altitudeMeters: base.altitudeMeters,
            speedMetersPerSecond: 80,
            courseDegrees: base.courseDegrees,
            recordedAt: base.recordedAt,
            receivedAt: base.receivedAt,
            provider: base.provider
        )
        return observations
    }

    /// Poor accuracy samples that future rules should de-weight or drop.
    static func poorAccuracySequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        makeSequence(
            idPrefix: "poor-accuracy",
            personID: personID,
            baseDate: baseDate,
            count: 4,
            interval: 15,
            latitude: 37.76000,
            longitude: -122.43000,
            accuracy: 90,
            speed: 1.5,
            stepLatitudeDelta: 0.00013,
            stepLongitudeDelta: 0
        )
    }

    /// Out-of-order timestamps (sorted windows must still work).
    static func outOfOrderSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        let ordered = walkingSequence(personID: personID, baseDate: baseDate)
        guard ordered.count >= 4 else { return ordered }
        return [ordered[2], ordered[0], ordered[3], ordered[1]] + Array(ordered.dropFirst(4))
    }

    /// Single stale fix older than the inference window.
    static func staleSingleObservation(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        [
            makeObservation(
                id: "stale-0",
                personID: personID,
                latitude: 37.7500,
                longitude: -122.4000,
                accuracy: 10,
                recordedAt: baseDate.addingTimeInterval(
                    -(ActivityInferenceConfiguration.maxObservationWindowAge + 120)
                ),
                receivedAt: baseDate,
                speed: 1.0
            ),
        ]
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

    private static func makeObservation(
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
