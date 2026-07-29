//
//  PresenceActivityCompositionTests.swift
//  PushTests
//
//  Issue #105 — pure composition of place + dwell + inference → presence activity.
//

import XCTest
@testable import Push

final class PresenceActivityCompositionTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fallback order

    func testConfidentPlaceBeatsMotionAndDwell() {
        let outcome = resolvedOutcome(name: "Crunch Fitness", id: "crunch")
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.walking, confidence: .high),
            fallbackActivity: .walking,
            placeResolution: outcome,
            isConfirmedDwelling: true
        )
        XCTAssertEqual(composition.activity.name, "At Crunch Fitness")
        XCTAssertEqual(composition.activity.symbolName, "mappin.and.ellipse")
        XCTAssertEqual(composition.placeID, "crunch")
        XCTAssertEqual(composition.statusNote, "At Crunch Fitness")
        XCTAssertEqual(composition.source, .inference)
        XCTAssertEqual(composition.confidence, .high)
    }

    func testConfirmedDwellWithoutPlaceIsChilling() {
        let ambiguous = PlaceResolutionOutcome(
            dwellSessionID: "d1",
            status: .ambiguous,
            selected: nil,
            candidates: [
                ResolvedPlaceCandidate(
                    id: "a", name: "A", latitude: 37.77, longitude: -122.42,
                    category: nil, distanceMeters: 10, score: 0.7
                ),
            ],
            geographicFallback: nil,
            resolvedAt: base,
            centroidLatitude: 37.77,
            centroidLongitude: -122.42
        )
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.stationary, confidence: .low),
            fallbackActivity: .nearby,
            placeResolution: ambiguous,
            isConfirmedDwelling: true
        )
        XCTAssertEqual(composition.activity, .chilling)
        XCTAssertNil(composition.placeID)
        XCTAssertNil(composition.statusNote)
        XCTAssertEqual(composition.source, .inference)
    }

    func testEmptyResolutionWhileDwellingIsChilling() {
        let empty = PlaceResolutionOutcome(
            dwellSessionID: "d1",
            status: .empty,
            selected: nil,
            candidates: [],
            geographicFallback: nil,
            resolvedAt: base,
            centroidLatitude: 37.77,
            centroidLongitude: -122.42
        )
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.unknown, confidence: .low),
            fallbackActivity: nil,
            placeResolution: empty,
            isConfirmedDwelling: true
        )
        XCTAssertEqual(composition.activity.name, "Chilling")
    }

    func testWalkingDrivingMovingAndNearbyWithoutDwell() {
        XCTAssertEqual(
            composeMotion(.walking).activity, .walking
        )
        XCTAssertEqual(
            composeMotion(.driving).activity, .driving
        )
        XCTAssertEqual(
            composeMotion(.moving).activity.name, "Moving"
        )
        XCTAssertEqual(
            composeMotion(.stationary).activity, .nearby
        )
        XCTAssertEqual(
            composeMotion(.unknown).activity, .nearby
        )
        XCTAssertEqual(composeMotion(.unknown).source, .location)
        XCTAssertEqual(composeMotion(.walking).source, .inference)
    }

    func testUnknownHoldsFallbackActivityWhenNotDwelling() {
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.unknown, confidence: .low),
            fallbackActivity: .driving,
            placeResolution: nil,
            isConfirmedDwelling: false
        )
        XCTAssertEqual(composition.activity, .driving)
        XCTAssertEqual(composition.source, .location)
        XCTAssertNil(composition.placeID)
    }

    func testAmbiguousDoesNotAttachPlaceName() {
        let outcome = PlaceResolutionOutcome(
            dwellSessionID: "d1",
            status: .ambiguous,
            selected: ResolvedPlaceCandidate(
                id: "x", name: "Should Not Attach", latitude: 0, longitude: 0,
                category: nil, distanceMeters: 5, score: 0.6
            ),
            candidates: [],
            geographicFallback: nil,
            resolvedAt: base,
            centroidLatitude: 0,
            centroidLongitude: 0
        )
        // selected set but status not .resolved → must not use place
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.chilling),
            fallbackActivity: nil,
            placeResolution: outcome,
            isConfirmedDwelling: true
        )
        XCTAssertEqual(composition.activity, .chilling)
        XCTAssertNil(composition.placeID)
        XCTAssertFalse(composition.activity.name.contains("Should Not"))
    }

    func testBlankPlaceNameDoesNotAttach() {
        let outcome = PlaceResolutionOutcome(
            dwellSessionID: "d1",
            status: .resolved,
            selected: ResolvedPlaceCandidate(
                id: "blank", name: "   ", latitude: 1, longitude: 2,
                category: nil, distanceMeters: 1, score: 0.99
            ),
            candidates: [],
            geographicFallback: nil,
            resolvedAt: base,
            centroidLatitude: 1,
            centroidLongitude: 2
        )
        let composition = ActivityInferencePresentation.compose(
            inferred: result(.stationary),
            fallbackActivity: nil,
            placeResolution: outcome,
            isConfirmedDwelling: true
        )
        XCTAssertEqual(composition.activity, .chilling)
        XCTAssertNil(composition.placeID)
    }

    // MARK: - Apply + write mapping

    func testApplyMutatesDraftAndPayload() {
        var draft = PresenceStatusDraft(
            availability: .freeNow,
            isPublished: true,
            activity: .nearby,
            latitude: 37.77,
            longitude: -122.42,
            confidence: .medium,
            observedAt: base,
            source: .location
        )
        ActivityInferencePresentation.apply(
            result(.walking),
            fallbackActivity: nil,
            placeResolution: resolvedOutcome(name: "Starbucks", id: "sbux"),
            isConfirmedDwelling: true,
            to: &draft
        )
        XCTAssertEqual(draft.activity.name, "At Starbucks")
        XCTAssertEqual(draft.placeID, "sbux")
        XCTAssertEqual(draft.statusNote, "At Starbucks")

        let payload = CurrentPresenceWriteMapping.payload(
            userID: "user-1",
            draft: draft,
            now: base
        )
        XCTAssertEqual(payload.activity_name, "At Starbucks")
        XCTAssertEqual(payload.activity_symbol, "mappin.and.ellipse")
        XCTAssertEqual(payload.place_id, "sbux")
        XCTAssertEqual(payload.status_note, "At Starbucks")
        XCTAssertEqual(payload.source, "inference")
    }

    func testClearPlaceOnApplyWithoutResolution() {
        var draft = PresenceStatusDraft(
            availability: .busy,
            isPublished: true,
            activity: .atPlace("Old Place"),
            placeID: "old",
            statusNote: "At Old Place",
            latitude: 37.77,
            longitude: -122.42,
            confidence: .high,
            observedAt: base,
            source: .inference
        )
        ActivityInferencePresentation.apply(
            result(.walking, confidence: .high),
            fallbackActivity: nil,
            placeResolution: nil,
            isConfirmedDwelling: false,
            to: &draft
        )
        XCTAssertEqual(draft.activity, .walking)
        XCTAssertNil(draft.placeID)
        XCTAssertNil(draft.statusNote)
    }

    func testKindPresenceActivityLabels() {
        XCTAssertEqual(InferredActivityKind.moving.presenceActivity.name, "Moving")
        XCTAssertEqual(InferredActivityKind.chilling.presenceActivity, .chilling)
        XCTAssertEqual(PresenceActivity.atPlace("Gym").name, "At Gym")
    }

    // MARK: - Remote row mapping

    func testRemoteRowCarriesAtPlaceActivity() {
        let row = CurrentPresenceRow.fixture(
            userID: "friend",
            activityName: "At Crunch Fitness",
            activitySymbol: "mappin.and.ellipse",
            lat: 37.77,
            lng: -122.42,
            updatedAt: "2030-01-01T12:00:00Z",
            source: "inference"
        )
        let status = row.presenceStatus()
        XCTAssertEqual(status?.activity.name, "At Crunch Fitness")
        let place = row.syntheticPlace()
        XCTAssertEqual(place?.name, "At Crunch Fitness")
    }

    // MARK: - Helpers

    private func composeMotion(_ kind: InferredActivityKind) -> PresenceActivityComposition {
        ActivityInferencePresentation.compose(
            inferred: result(kind),
            fallbackActivity: nil,
            placeResolution: nil,
            isConfirmedDwelling: false
        )
    }

    private func result(
        _ kind: InferredActivityKind,
        confidence: PresenceStatus.Confidence = .medium
    ) -> InferredActivityResult {
        InferredActivityResult(
            kind: kind,
            inferredAt: base,
            confidence: confidence
        )
    }

    private func resolvedOutcome(name: String, id: String) -> PlaceResolutionOutcome {
        PlaceResolutionOutcome(
            dwellSessionID: "d1",
            status: .resolved,
            selected: ResolvedPlaceCandidate(
                id: id,
                name: name,
                latitude: 37.77,
                longitude: -122.42,
                category: "poi",
                distanceMeters: 8,
                score: 0.95
            ),
            candidates: [],
            geographicFallback: nil,
            resolvedAt: base,
            centroidLatitude: 37.77,
            centroidLongitude: -122.42
        )
    }
}
