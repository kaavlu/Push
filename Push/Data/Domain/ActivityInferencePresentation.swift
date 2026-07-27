//
//  ActivityInferencePresentation.swift
//  Push
//
//  Issue #94 (I3) — map inferred activity kinds onto presence draft fields.
//  Uses existing activity_name / activity_symbol (no schema migration).
//  Labels are durable pipeline strings — not hedged UI copy.
//

import Foundation

extension PresenceActivity {
    /// Phase 1 default when inference is unknown or stationary.
    static let nearby = PresenceActivity(name: "Nearby", symbolName: "location.fill")
}

extension InferredActivityKind {
    /// Stable presence activity for sync / builders (not friend-facing chrome).
    var presenceActivity: PresenceActivity {
        switch self {
        case .unknown, .stationary:
            return .nearby
        case .chilling:
            return PresenceActivity(name: "Chilling", symbolName: "sofa.fill")
        case .walking:
            return PresenceActivity(name: "Walking", symbolName: "figure.walk")
        case .driving:
            return PresenceActivity(name: "Driving", symbolName: "car.fill")
        case .moving:
            return PresenceActivity(name: "On the move", symbolName: "figure.walk.motion")
        }
    }

    /// Classified motion uses inference source; unknown keeps location source.
    var presenceSource: PresenceStatus.Source {
        switch self {
        case .unknown:
            return .location
        case .stationary, .chilling, .walking, .driving, .moving:
            return .inference
        }
    }
}

enum ActivityInferencePresentation {
    /// Activity + confidence + source to apply onto a location presence draft.
    /// Unknown inference keeps `fallbackActivity` when provided (heartbeat hold).
    static func draftFields(
        for result: InferredActivityResult,
        fallbackActivity: PresenceActivity?
    ) -> (activity: PresenceActivity, confidence: PresenceStatus.Confidence, source: PresenceStatus.Source) {
        if result.kind == .unknown {
            return (
                fallbackActivity ?? .nearby,
                result.confidence,
                .location
            )
        }
        return (
            result.kind.presenceActivity,
            result.confidence,
            result.kind.presenceSource
        )
    }

    /// Mutates a draft in place with resolved activity fields.
    static func apply(
        _ result: InferredActivityResult,
        fallbackActivity: PresenceActivity?,
        to draft: inout PresenceStatusDraft
    ) {
        let fields = draftFields(for: result, fallbackActivity: fallbackActivity)
        draft.activity = fields.activity
        draft.confidence = fields.confidence
        draft.source = fields.source
    }
}
