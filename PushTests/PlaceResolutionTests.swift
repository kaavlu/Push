//
//  PlaceResolutionTests.swift
//  PushTests
//
//  Issue #101 (I3) — place ranking + session place-resolution orchestration.
//  No MapKit network, GPS, or UI.
//

import XCTest
@testable import Push

final class PlaceResolutionTests: XCTestCase {

    private let base = DwellDetectionFixtures.baseDate
    private let dwellLat = 37.7749
    private let dwellLon = -122.4194

    // MARK: - Ranker: clear match

    func testOneClearNearbyCandidateResolves() {
        let request = makeRequest(accuracy: 10)
        let payload = PlaceSearchPayload(
            candidates: [
                UnrankedPlaceCandidate(
                    id: "crunch",
                    name: "Crunch Fitness",
                    latitude: dwellLat + 0.00005,
                    longitude: dwellLon,
                    category: "fitness"
                ),
            ]
        )
        let outcome = PlaceCandidateRanker.rank(request: request, payload: payload)
        XCTAssertEqual(outcome.status, .resolved)
        XCTAssertEqual(outcome.selected?.name, "Crunch Fitness")
        XCTAssertEqual(outcome.confidentPlaceName, "Crunch Fitness")
        XCTAssertEqual(outcome.candidates.count, 1)
    }

    // MARK: - Ambiguity

    func testMultipleNeighboringBusinessesAreAmbiguous() {
        let request = makeRequest(accuracy: 10)
        // Two equally close cafes ~15 m away on opposite sides.
        let payload = PlaceSearchPayload(
            candidates: [
                UnrankedPlaceCandidate(
                    id: "sbux",
                    name: "Starbucks",
                    latitude: dwellLat + 0.00012,
                    longitude: dwellLon,
                    category: "cafe"
                ),
                UnrankedPlaceCandidate(
                    id: "blue",
                    name: "Blue Bottle",
                    latitude: dwellLat - 0.00012,
                    longitude: dwellLon,
                    category: "cafe"
                ),
            ]
        )
        let outcome = PlaceCandidateRanker.rank(request: request, payload: payload)
        XCTAssertEqual(outcome.status, .ambiguous)
        XCTAssertNil(outcome.selected)
        XCTAssertNil(outcome.confidentPlaceName)
        XCTAssertEqual(outcome.candidates.count, 2)
    }

    // MARK: - Empty / geographic

    func testNoNearbyPOIsEmptyWithoutFallback() {
        let request = makeRequest(accuracy: 10)
        let outcome = PlaceCandidateRanker.rank(
            request: request,
            payload: PlaceSearchPayload()
        )
        XCTAssertEqual(outcome.status, .empty)
        XCTAssertNil(outcome.selected)
    }

    func testNoNearbyPOIsUsesGeographicFallback() {
        let request = makeRequest(accuracy: 10)
        let payload = PlaceSearchPayload(
            geographicFallback: GeographicPlaceContext(displayName: "Pacific Beach")
        )
        let outcome = PlaceCandidateRanker.rank(request: request, payload: payload)
        XCTAssertEqual(outcome.status, .geographicOnly)
        XCTAssertEqual(outcome.geographicFallback?.displayName, "Pacific Beach")
        XCTAssertNil(outcome.selected)
    }

    // MARK: - Accuracy / distance

    func testPoorAccuracyBlocksWeakMatch() {
        let request = makeRequest(accuracy: 55)
        // Far-ish candidate that might pass with good accuracy but not poor.
        let payload = PlaceSearchPayload(
            candidates: [
                UnrankedPlaceCandidate(
                    id: "far",
                    name: "Edge Cafe",
                    latitude: dwellLat + 0.0008,
                    longitude: dwellLon,
                    category: "cafe"
                ),
            ]
        )
        let outcome = PlaceCandidateRanker.rank(request: request, payload: payload)
        XCTAssertNotEqual(outcome.status, .resolved)
        XCTAssertNil(outcome.selected)
    }

    func testCandidateOutsideLikelyAreaIsPenalized() {
        let request = makeRequest(accuracy: 8)
        let inside = UnrankedPlaceCandidate(
            id: "near",
            name: "Near Spot",
            latitude: dwellLat + 0.00005,
            longitude: dwellLon,
            category: "cafe"
        )
        let outside = UnrankedPlaceCandidate(
            id: "far",
            name: "Far Spot",
            latitude: dwellLat + 0.0010,
            longitude: dwellLon,
            category: "cafe"
        )
        let outcome = PlaceCandidateRanker.rank(
            request: request,
            payload: PlaceSearchPayload(candidates: [outside, inside])
        )
        XCTAssertEqual(outcome.candidates.first?.id, "near")
        XCTAssertEqual(outcome.status, .resolved)
        XCTAssertEqual(outcome.selected?.id, "near")
    }

    func testPreviousMatchBoostBreaksTie() {
        let request = makeRequest(accuracy: 10, previousID: "blue")
        // Mid-range distance so scores are not clamped at 1.0; same offset each way.
        let payload = PlaceSearchPayload(
            candidates: [
                UnrankedPlaceCandidate(
                    id: "sbux",
                    name: "Starbucks",
                    latitude: dwellLat,
                    longitude: dwellLon + 0.00040,
                    category: "cafe"
                ),
                UnrankedPlaceCandidate(
                    id: "blue",
                    name: "Blue Bottle",
                    latitude: dwellLat,
                    longitude: dwellLon - 0.00040,
                    category: "cafe"
                ),
            ]
        )
        let outcome = PlaceCandidateRanker.rank(request: request, payload: payload)
        XCTAssertEqual(outcome.status, .resolved)
        XCTAssertEqual(outcome.selected?.id, "blue")
        guard let top = outcome.candidates.first,
              let second = outcome.candidates.dropFirst().first
        else {
            return XCTFail("expected two ranked candidates")
        }
        XCTAssertGreaterThanOrEqual(
            top.score - second.score,
            PlaceResolutionConfiguration.ambiguityScoreDelta
        )
    }

    // MARK: - Fixed resolver

    func testFixedResolverThrowsProviderFailure() async {
        let resolver = FixedPlaceResolver(error: PlaceResolutionError.providerFailed)
        let request = makeRequest(accuracy: 10)
        do {
            _ = try await resolver.resolve(request)
            XCTFail("expected throw")
        } catch let error as PlaceResolutionError {
            XCTAssertEqual(error, .providerFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - Session orchestration

    @MainActor
    func testArrivalTriggersOneLookupNotEveryFix() async {
        let resolver = CountingPlaceResolver(
            payload: PlaceSearchPayload(
                candidates: [
                    UnrankedPlaceCandidate(
                        id: "crunch",
                        name: "Crunch Fitness",
                        latitude: dwellLat,
                        longitude: dwellLon,
                        category: "fitness"
                    ),
                ]
            )
        )
        let session = makeSession(resolver: resolver)
        await session.startIfEligible()

        let sequence = DwellDetectionFixtures.sustainedDwellSequence()
        for observation in sequence {
            session.process(observation)
        }
        await waitUntil { session.activePlaceResolutionForTesting != nil }

        XCTAssertEqual(session.dwellStateForTesting.phase, .dwelling)
        XCTAssertEqual(session.activePlaceResolutionForTesting?.status, .resolved)
        XCTAssertEqual(session.activePlaceResolutionForTesting?.selected?.name, "Crunch Fitness")
        // Arrival schedules once; later inliers must not re-hit the resolver.
        XCTAssertEqual(resolver.resolveCount, 1)
        XCTAssertEqual(session.placeResolveAttemptsForTesting, 1)

        session.shutdown()
        XCTAssertNil(session.activePlaceResolutionForTesting)
    }

    @MainActor
    func testDepartureClearsActivePlaceContext() async {
        let resolver = CountingPlaceResolver(
            payload: PlaceSearchPayload(
                candidates: [
                    UnrankedPlaceCandidate(
                        id: "sbux",
                        name: "Starbucks",
                        latitude: dwellLat,
                        longitude: dwellLon,
                        category: "cafe"
                    ),
                ]
            )
        )
        let session = makeSession(resolver: resolver)
        await session.startIfEligible()

        for observation in DwellDetectionFixtures.dwellThenExitSequence() {
            session.process(observation)
        }
        // May have resolved then cleared — wait briefly then assert cleared.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(session.dwellStateForTesting.phase, .moving)
        XCTAssertNil(session.activePlaceResolutionForTesting)
        session.shutdown()
    }

    @MainActor
    func testResolverFailureDoesNotBreakPresencePipeline() async {
        let resolver = CountingPlaceResolver(error: PlaceResolutionError.providerFailed)
        let sync = FakePresenceSync()
        let session = makeSession(resolver: resolver, sync: sync)
        await session.startIfEligible()

        for observation in DwellDetectionFixtures.sustainedDwellSequence() {
            session.process(observation)
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(session.dwellStateForTesting.phase, .dwelling)
        XCTAssertNil(session.activePlaceResolutionForTesting)
        // Presence path still enqueued at least the first publish.
        XCTAssertFalse(sync.drafts.isEmpty)
        session.shutdown()
    }

    @MainActor
    func testNoOpResolverLeavesEmptyOutcomePath() async {
        let session = makeSession(resolver: NoOpPlaceResolver())
        await session.startIfEligible()
        for observation in DwellDetectionFixtures.sustainedDwellSequence() {
            session.process(observation)
        }
        await waitUntil {
            session.activePlaceResolutionForTesting?.status == .empty
                || session.placeResolveAttemptsForTesting >= 1
        }
        // NoOp returns empty synchronously via Task — may still apply.
        if let outcome = session.activePlaceResolutionForTesting {
            XCTAssertEqual(outcome.status, .empty)
        }
        session.shutdown()
    }

    // MARK: - Config

    func testConfigurationCoherent() {
        XCTAssertGreaterThan(PlaceResolutionConfiguration.searchRadiusMeters, 0)
        XCTAssertGreaterThan(PlaceResolutionConfiguration.minScoreForSelection, 0.5)
        XCTAssertGreaterThan(PlaceResolutionConfiguration.ambiguityScoreDelta, 0)
        XCTAssertGreaterThan(
            PlaceResolutionConfiguration.centroidChangeReresolveMeters,
            0
        )
        XCTAssertGreaterThanOrEqual(
            PlaceResolutionConfiguration.maxResolveAttemptsPerDwell,
            1
        )
    }

    // MARK: - Helpers

    private func makeRequest(
        accuracy: Double,
        previousID: String? = nil
    ) -> PlaceResolutionRequest {
        PlaceResolutionRequest(
            dwellSessionID: "dwell-test",
            centroidLatitude: dwellLat,
            centroidLongitude: dwellLon,
            representativeAccuracyMeters: accuracy,
            dwellRadiusMeters: DwellDetectionConfiguration.dwellRadiusMeters,
            previousResolvedPlaceID: previousID,
            evaluationTime: base
        )
    }

    @MainActor
    private func makeSession(
        resolver: any PlaceResolving,
        sync: PresenceSyncing = FakePresenceSync()
    ) -> LocationSession {
        LocationSession(
            provider: FakeLocationProvider(authorizationState: .whenInUse),
            validator: AcceptAllLocationValidator(),
            placeResolver: resolver,
            sync: sync,
            isPresencePublishingEnabled: true,
            isTrackingDesired: true,
            now: { self.base.addingTimeInterval(20 * 60) }
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    }
}

// MARK: - Counting resolver

/// Records resolve call count; returns canned payload or throws.
final class CountingPlaceResolver: PlaceResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var payload: PlaceSearchPayload
    var error: Error?

    init(payload: PlaceSearchPayload = PlaceSearchPayload(), error: Error? = nil) {
        self.payload = payload
        self.error = error
    }

    var resolveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func resolve(_ request: PlaceResolutionRequest) async throws -> PlaceResolutionOutcome {
        lock.lock()
        _count += 1
        lock.unlock()
        if let error { throw error }
        return PlaceCandidateRanker.rank(request: request, payload: payload)
    }
}
