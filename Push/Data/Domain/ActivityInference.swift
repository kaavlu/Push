//
//  ActivityInference.swift
//  Push
//
//  Issue #92 (I1) — domain types for local activity inference.
//  No production rules, LocationSession wiring, or Supabase.
//

import Foundation

// MARK: - Activity kinds

/// Durable motion / social-context class inferred from location observations.
/// Independent of manual availability (Free now / Busy / Ghost).
///
/// `arrived` / `left` are intentionally omitted — they are transition events
/// for a later issue, not durable states.
enum InferredActivityKind: String, Codable, Sendable, Equatable, CaseIterable {
    /// Insufficient evidence or no-op engine result.
    case unknown
    /// Little or no displacement over the evaluation window.
    case stationary
    /// Generic motion that is not confidently walking or driving.
    case moving
    /// Pedestrian-scale sustained motion.
    case walking
    /// Vehicle-scale sustained motion.
    case driving
    /// Sustained low-movement dwell that is socially "hanging out" (not just
    /// a brief stop). Distinct from raw `stationary`.
    case chilling
}

// MARK: - Result

/// App-owned inference output. Internal pipeline type — not friend-facing copy.
/// Confidence is evidence strength for the pipeline; do not surface hedged
/// labels such as "likely walking" in product UI from this type alone.
struct InferredActivityResult: Codable, Equatable, Sendable {
    let kind: InferredActivityKind
    /// When the engine produced this classification.
    let inferredAt: Date
    /// Internal evidence strength (not user-facing wording).
    let confidence: PresenceStatus.Confidence
    /// Optional soft expiry for consumers that cache the last result.
    let validUntil: Date?

    init(
        kind: InferredActivityKind,
        inferredAt: Date,
        confidence: PresenceStatus.Confidence,
        validUntil: Date? = nil
    ) {
        self.kind = kind
        self.inferredAt = inferredAt
        self.confidence = confidence
        self.validUntil = validUntil
    }

    /// Whether a cached result is still usable at `now`.
    func isValid(at now: Date) -> Bool {
        guard let validUntil else { return true }
        return now < validUntil
    }

    /// Safe default when history is empty or the engine has no rules yet.
    static func unknown(
        at inferredAt: Date,
        confidence: PresenceStatus.Confidence = .low,
        validUntil: Date? = nil
    ) -> InferredActivityResult {
        InferredActivityResult(
            kind: .unknown,
            inferredAt: inferredAt,
            confidence: confidence,
            validUntil: validUntil
        )
    }
}

// MARK: - Engine protocol

/// Pure / injectable seam for classifying recent location observations.
/// Implementations must stay free of Core Location, network I/O, and UI.
///
/// Input is app-owned `LocationObservation` values (Doubles only). Callers
/// may pass validated history; the engine itself does not require
/// `ValidatedObservation`.
protocol ActivityInferenceEngine: Sendable {
    /// Classify activity from a chronological observation window.
    /// Empty or insufficient windows must return `.unknown` (never invent).
    func infer(
        from observations: [LocationObservation],
        at evaluationTime: Date
    ) -> InferredActivityResult
}

// MARK: - Unknown-only implementation

/// I1 / default engine — always returns `.unknown`.
/// Safe to inject anywhere before deterministic rules (Issue #93) land.
struct UnknownActivityInferenceEngine: ActivityInferenceEngine {
    /// Soft validity window for the constant unknown result (caching seam).
    var resultValidity: TimeInterval

    init(resultValidity: TimeInterval = ActivityInferenceConfiguration.unknownResultValidity) {
        self.resultValidity = resultValidity
    }

    func infer(
        from observations: [LocationObservation],
        at evaluationTime: Date
    ) -> InferredActivityResult {
        _ = observations
        return .unknown(
            at: evaluationTime,
            confidence: .low,
            validUntil: evaluationTime.addingTimeInterval(resultValidity)
        )
    }
}
