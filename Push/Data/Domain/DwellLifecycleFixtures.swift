//
//  DwellLifecycleFixtures.swift
//  Push
//
//  Issue #100 (I2) — arrival/departure lifecycle observation sequences.
//

import Foundation

extension DwellDetectionFixtures {
    /// Sustained dwell then a clear exit (large jump + high speed).
    /// Exit streak spans ≥ minimumDepartureDuration with ≥ minimumDepartureSampleCount.
    static func dwellThenExitSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = sustainedDwellSequence(personID: personID, baseDate: baseDate)
        guard let last = observations.last else { return observations }
        // 4 samples × 40s = 120s outside (> 90s departure duration).
        for index in 0..<4 {
            let t = last.recordedAt.addingTimeInterval(TimeInterval(index + 1) * 40)
            observations.append(
                makeObservation(
                    id: "exit-\(index)",
                    personID: personID,
                    latitude: last.latitude + 0.01,
                    longitude: last.longitude,
                    accuracy: 10,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 5
                )
            )
        }
        return observations
    }

    /// Confirmed dwell, then walk around a large venue (~60–80 m from centroid).
    /// Must remain dwelling (near-zone, not departure).
    static func largeVenueWanderSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = sustainedDwellSequence(personID: personID, baseDate: baseDate)
        guard let last = observations.last else { return observations }
        // ~0.0007° lat ≈ 78 m — outside 40 m inlier, inside 100 m departure radius.
        let nearOffsets: [(Double, Double)] = [
            (0.00070, 0),
            (0.00065, 0.00020),
            (0.00055, -0.00015),
            (0.00075, 0.00010),
            (0.00060, 0),
        ]
        for (index, offset) in nearOffsets.enumerated() {
            let t = last.recordedAt.addingTimeInterval(TimeInterval(index + 1) * 30)
            observations.append(
                makeObservation(
                    id: "venue-\(index)",
                    personID: personID,
                    latitude: 37.7749 + offset.0,
                    longitude: -122.4194 + offset.1,
                    accuracy: 12,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 0.3
                )
            )
        }
        return observations
    }

    /// One inaccurate fix during a dwell — must be ignored (no departure).
    static func dwellWithSingleBadFixSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = sustainedDwellSequence(personID: personID, baseDate: baseDate)
        guard let last = observations.last else { return observations }
        let badTime = last.recordedAt.addingTimeInterval(20)
        observations.append(
            makeObservation(
                id: "bad-fix",
                personID: personID,
                latitude: last.latitude + 0.05,
                longitude: last.longitude,
                accuracy: 90,
                recordedAt: badTime,
                receivedAt: badTime,
                speed: 0.1
            )
        )
        for index in 0..<3 {
            let t = badTime.addingTimeInterval(TimeInterval(index + 1) * 30)
            observations.append(
                makeObservation(
                    id: "after-bad-\(index)",
                    personID: personID,
                    latitude: last.latitude,
                    longitude: last.longitude,
                    accuracy: 10,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 0.05
                )
            )
        }
        return observations
    }

    /// Drive in (high speed), park, then remain — one dwell, no flip-flop.
    static func parkingThenStaySequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations: [LocationObservation] = []
        for index in 0..<4 {
            let t = baseDate.addingTimeInterval(TimeInterval(index) * 10)
            observations.append(
                makeObservation(
                    id: "drive-\(index)",
                    personID: personID,
                    latitude: 37.7700 + Double(index) * 0.001,
                    longitude: -122.4200,
                    accuracy: 15,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 12
                )
            )
        }
        let parkStart = baseDate.addingTimeInterval(50)
        observations.append(contentsOf: sustainedDwellSequence(
            personID: personID,
            baseDate: parkStart,
            latitude: 37.7740,
            longitude: -122.4200,
            idPrefix: "park"
        ))
        return observations
    }

    /// Full lifecycle: dwell → leave → dwell elsewhere (re-arrival).
    static func reArrivalSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = dwellThenExitSequence(personID: personID, baseDate: baseDate)
        guard let last = observations.last else { return observations }
        let secondStart = last.recordedAt.addingTimeInterval(30)
        observations.append(contentsOf: sustainedDwellSequence(
            personID: personID,
            baseDate: secondStart,
            latitude: 37.7840,
            longitude: -122.4090,
            idPrefix: "second"
        ))
        return observations
    }

    /// Brief excursion outside departure radius that returns before hysteresis.
    static func briefLeaveThenReturnSequence(
        personID: Person.ID = defaultPersonID,
        baseDate: Date = baseDate
    ) -> [LocationObservation] {
        var observations = sustainedDwellSequence(personID: personID, baseDate: baseDate)
        guard let last = observations.last else { return observations }
        for index in 0..<2 {
            let t = last.recordedAt.addingTimeInterval(TimeInterval(index + 1) * 20)
            observations.append(
                makeObservation(
                    id: "brief-\(index)",
                    personID: personID,
                    latitude: last.latitude + 0.01,
                    longitude: last.longitude,
                    accuracy: 12,
                    recordedAt: t,
                    receivedAt: t,
                    speed: 0.2
                )
            )
        }
        let returnTime = last.recordedAt.addingTimeInterval(70)
        observations.append(
            makeObservation(
                id: "brief-return",
                personID: personID,
                latitude: last.latitude,
                longitude: last.longitude,
                accuracy: 10,
                recordedAt: returnTime,
                receivedAt: returnTime,
                speed: 0.05
            )
        )
        return observations
    }
}
