//
//  DeterministicDwellDetector+Support.swift
//  Push
//
//  Issue #99 / #100 — private working types for DeterministicDwellDetector.
//

import Foundation

// MARK: - Working cluster

struct DwellWorkingCluster {
    var startedAt: Date
    var lastConfirmedAt: Date
    var sampleCount: Int
    var sumLatitude: Double
    var sumLongitude: Double
    var sumAccuracy: Double
    /// Samples that still contribute to the running centroid mean.
    var unlockedSampleCount: Int
    var centroidLatitude: Double
    var centroidLongitude: Double
    var centroidLocked: Bool

    init(startedAt: Date, centroidLocked: Bool) {
        self.startedAt = startedAt
        self.lastConfirmedAt = startedAt
        self.sampleCount = 0
        self.sumLatitude = 0
        self.sumLongitude = 0
        self.sumAccuracy = 0
        self.unlockedSampleCount = 0
        self.centroidLatitude = 0
        self.centroidLongitude = 0
        self.centroidLocked = centroidLocked
    }

    mutating func accept(_ observation: LocationObservation) {
        lastConfirmedAt = observation.recordedAt
        sampleCount += 1
        sumAccuracy += observation.horizontalAccuracyMeters

        if !centroidLocked {
            sumLatitude += observation.latitude
            sumLongitude += observation.longitude
            unlockedSampleCount += 1
            centroidLatitude = sumLatitude / Double(unlockedSampleCount)
            centroidLongitude = sumLongitude / Double(unlockedSampleCount)
            if unlockedSampleCount >= DwellDetectionConfiguration.centroidLockSampleCount {
                centroidLocked = true
            }
        }
    }

    var snapshot: DwellClusterSnapshot {
        let accuracy = sampleCount > 0
            ? sumAccuracy / Double(sampleCount)
            : 0
        return DwellClusterSnapshot(
            centroidLatitude: centroidLatitude,
            centroidLongitude: centroidLongitude,
            startedAt: startedAt,
            lastConfirmedAt: lastConfirmedAt,
            sampleCount: sampleCount,
            representativeAccuracyMeters: accuracy
        )
    }
}

// MARK: - Departure streak

struct DwellDepartureStreak {
    var firstAt: Date
    var lastAt: Date
    var sampleCount: Int

    init(firstAt: Date, sampleCount: Int) {
        self.firstAt = firstAt
        self.lastAt = firstAt
        self.sampleCount = sampleCount
    }
}

// MARK: - Session updates

extension DwellLifecycleSession {
    func updating(from snapshot: DwellClusterSnapshot) -> DwellLifecycleSession {
        DwellLifecycleSession(
            id: id,
            centroidLatitude: snapshot.centroidLatitude,
            centroidLongitude: snapshot.centroidLongitude,
            startedAt: startedAt,
            arrivedAt: arrivedAt,
            departedAt: nil,
            lastConfirmedAt: snapshot.lastConfirmedAt,
            sampleCount: snapshot.sampleCount,
            representativeAccuracyMeters: snapshot.representativeAccuracyMeters
        )
    }

    func refreshingLastConfirmed(at date: Date) -> DwellLifecycleSession {
        DwellLifecycleSession(
            id: id,
            centroidLatitude: centroidLatitude,
            centroidLongitude: centroidLongitude,
            startedAt: startedAt,
            arrivedAt: arrivedAt,
            departedAt: nil,
            lastConfirmedAt: date,
            sampleCount: sampleCount,
            representativeAccuracyMeters: representativeAccuracyMeters
        )
    }

    func completing(
        departedAt: Date,
        lastConfirmedAt: Date,
        sampleCount: Int,
        representativeAccuracyMeters: Double
    ) -> DwellLifecycleSession {
        DwellLifecycleSession(
            id: id,
            centroidLatitude: centroidLatitude,
            centroidLongitude: centroidLongitude,
            startedAt: startedAt,
            arrivedAt: arrivedAt,
            departedAt: departedAt,
            lastConfirmedAt: lastConfirmedAt,
            sampleCount: sampleCount,
            representativeAccuracyMeters: representativeAccuracyMeters
        )
    }
}
