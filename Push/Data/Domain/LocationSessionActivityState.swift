//
//  LocationSessionActivityState.swift
//  Push
//
//  Issue #94 (I3) — observation window + last-inferred activity for LocationSession.
//  Pure bookkeeping; engine calls stay failure-safe for the publish path.
//

import Foundation

/// Recent accepted fixes and committed inference used by `LocationSession`.
struct LocationSessionActivityState: Equatable {
    /// Cap retained fixes so the buffer cannot grow unbounded while foreground.
    static let maxRetainedObservations = 64

    private(set) var recentObservations: [LocationObservation] = []
    /// Last engine output (may be `.unknown`).
    private(set) var lastInferred: InferredActivityResult?
    /// Last non-unknown result still useful for heartbeats / hold-through.
    private(set) var lastValid: InferredActivityResult?

    /// Append an accepted observation and drop aged / excess samples.
    mutating func recordAccepted(_ observation: LocationObservation, now: Date) {
        recentObservations.append(observation)
        trim(now: now)
    }

    /// Resolve activity for a publish trigger without throwing.
    /// Heartbeats / republish preserve the last valid kind when still fresh.
    mutating func resolve(
        engine: ActivityInferenceEngine,
        trigger: PresenceSyncTrigger,
        at evaluationTime: Date
    ) -> InferredActivityResult {
        if shouldPreserveLastValid(for: trigger, at: evaluationTime),
           let lastValid
        {
            return lastValid
        }

        let inferred = safeInfer(engine: engine, at: evaluationTime)
        lastInferred = inferred
        if inferred.kind != .unknown {
            lastValid = inferred
        }
        return inferred
    }

    /// Presentation activity for drafts when inference is unknown.
    func fallbackActivity(at evaluationTime: Date) -> PresenceActivity? {
        guard let lastValid, lastValid.kind != .unknown else { return nil }
        guard lastValid.isValid(at: evaluationTime) else { return nil }
        return lastValid.kind.presenceActivity
    }

    mutating func reset() {
        recentObservations = []
        lastInferred = nil
        lastValid = nil
    }

    // MARK: - Private

    private func shouldPreserveLastValid(
        for trigger: PresenceSyncTrigger,
        at evaluationTime: Date
    ) -> Bool {
        guard let lastValid, lastValid.kind != .unknown else { return false }
        guard lastValid.isValid(at: evaluationTime) else { return false }
        switch trigger {
        case .heartbeat, .republish:
            return true
        case .movement, .firstEligibleStart, .unpublish, .availabilityChange,
             .permissionRevoked, .sessionShutdown, .sharingPolicyReduced:
            return false
        }
    }

    private func safeInfer(
        engine: ActivityInferenceEngine,
        at evaluationTime: Date
    ) -> InferredActivityResult {
        // Engine is pure today; keep a single call site for future fallibility.
        engine.infer(
            from: recentObservations,
            previous: lastInferred,
            at: evaluationTime
        )
    }

    private mutating func trim(now: Date) {
        let earliest = now.addingTimeInterval(
            -ActivityInferenceConfiguration.maxObservationWindowAge
        )
        recentObservations.removeAll { observation in
            observation.recordedAt < earliest
        }
        if recentObservations.count > Self.maxRetainedObservations {
            let drop = recentObservations.count - Self.maxRetainedObservations
            recentObservations.removeFirst(drop)
        }
    }
}
