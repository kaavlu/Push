//
//  ActivityInferencePresentation.swift
//  Push
//
//  Issue #94 (I3) / #105 — map inferred activity + resolved place onto presence
//  draft fields. Uses existing activity_name / activity_symbol / place_id /
//  status_note (no schema migration). Labels are durable pipeline strings —
//  not hedged UI copy.
//

import Foundation

// MARK: - Canonical activity strings

extension PresenceActivity {
    /// Phase 1 default when inference is unknown or non-dwell stationary.
    static let nearby = PresenceActivity(name: "Nearby", symbolName: "location.fill")
    static let chilling = PresenceActivity(name: "Chilling", symbolName: "sofa.fill")
    static let walking = PresenceActivity(name: "Walking", symbolName: "figure.walk")
    static let driving = PresenceActivity(name: "Driving", symbolName: "car.fill")
    static let moving = PresenceActivity(name: "Moving", symbolName: "figure.walk.motion")

    /// Friend-visible place attachment. Prefer confident POI names only.
    static func atPlace(_ name: String) -> PresenceActivity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "a place" : trimmed
        return PresenceActivity(name: "At \(label)", symbolName: "mappin.and.ellipse")
    }
}

extension InferredActivityKind {
    /// Stable presence activity for sync / builders (not friend-facing chrome).
    var presenceActivity: PresenceActivity {
        switch self {
        case .unknown, .stationary:
            return .nearby
        case .chilling:
            return .chilling
        case .walking:
            return .walking
        case .driving:
            return .driving
        case .moving:
            return .moving
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

// MARK: - Composition result

/// Fields applied onto a location presence draft in one step.
struct PresenceActivityComposition: Equatable, Sendable {
    let activity: PresenceActivity
    let confidence: PresenceStatus.Confidence
    let source: PresenceStatus.Source
    /// Resolved POI id when a confident place is attached; otherwise nil.
    let placeID: Place.ID?
    /// Set to `At {place}` when attached so UI that prefixes "At " does not double.
    let statusNote: String?

    init(
        activity: PresenceActivity,
        confidence: PresenceStatus.Confidence,
        source: PresenceStatus.Source,
        placeID: Place.ID? = nil,
        statusNote: String? = nil
    ) {
        self.activity = activity
        self.confidence = confidence
        self.source = source
        self.placeID = placeID
        self.statusNote = statusNote
    }
}

// MARK: - Presentation

enum ActivityInferencePresentation {
    /// Canonical merge of place resolution + dwell + motion inference.
    ///
    /// Order (Issue #105):
    /// 1. Confident resolved place → At {place}
    /// 2. Confirmed dwell without reliable place → Chilling
    /// 3. Walking / Driving / Moving from inference
    /// 4. Otherwise Nearby (or heartbeat hold when unknown)
    static func compose(
        inferred: InferredActivityResult,
        fallbackActivity: PresenceActivity?,
        placeResolution: PlaceResolutionOutcome?,
        isConfirmedDwelling: Bool
    ) -> PresenceActivityComposition {
        if let place = confidentPlace(from: placeResolution) {
            let note = "At \(place.name)"
            return PresenceActivityComposition(
                activity: .atPlace(place.name),
                confidence: .high,
                source: .inference,
                placeID: place.id,
                statusNote: note
            )
        }

        if isConfirmedDwelling {
            return PresenceActivityComposition(
                activity: .chilling,
                confidence: maxConfidence(inferred.confidence, .medium),
                source: .inference,
                placeID: nil,
                statusNote: nil
            )
        }

        let fields = draftFields(for: inferred, fallbackActivity: fallbackActivity)
        return PresenceActivityComposition(
            activity: fields.activity,
            confidence: fields.confidence,
            source: fields.source,
            placeID: nil,
            statusNote: nil
        )
    }

    /// Activity + confidence + source for motion-only drafts (no place/dwell).
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

    /// Mutates a draft with composed activity / place fields.
    static func apply(
        _ result: InferredActivityResult,
        fallbackActivity: PresenceActivity?,
        placeResolution: PlaceResolutionOutcome? = nil,
        isConfirmedDwelling: Bool = false,
        to draft: inout PresenceStatusDraft
    ) {
        let fields = compose(
            inferred: result,
            fallbackActivity: fallbackActivity,
            placeResolution: placeResolution,
            isConfirmedDwelling: isConfirmedDwelling
        )
        draft.activity = fields.activity
        draft.confidence = fields.confidence
        draft.source = fields.source
        draft.placeID = fields.placeID
        draft.statusNote = fields.statusNote
    }

    // MARK: - Helpers

    private static func confidentPlace(
        from outcome: PlaceResolutionOutcome?
    ) -> ResolvedPlaceCandidate? {
        guard let outcome, outcome.status == .resolved else { return nil }
        guard let selected = outcome.selected else { return nil }
        let name = selected.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return selected
    }

    private static func maxConfidence(
        _ a: PresenceStatus.Confidence,
        _ b: PresenceStatus.Confidence
    ) -> PresenceStatus.Confidence {
        let rank: (PresenceStatus.Confidence) -> Int = {
            switch $0 {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            }
        }
        return rank(a) >= rank(b) ? a : b
    }
}
