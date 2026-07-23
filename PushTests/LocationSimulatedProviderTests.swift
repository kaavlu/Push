//
//  LocationSimulatedProviderTests.swift
//  PushTests
//
//  Issue #68 — SimulatedLocationProvider behavior.
//  No GPS hardware, real wall-clock sleeps, Core Location, or Supabase.
//

import XCTest
@testable import Push

@MainActor
final class LocationSimulatedProviderTests: XCTestCase {

    // MARK: - Emission order & lifecycle

    func testDoesNotEmitBeforeStart() async {
        let route = SimulatedLocationRouteFixtures.stationary()
        let provider = SimulatedLocationProvider(route: route, mode: .manual)
        let stream = provider.observations

        let collector = ObservationCollector(stream: stream)
        await collector.start()

        XCTAssertFalse(provider.advance())
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(collector.ids.isEmpty)
        XCTAssertFalse(provider.isUpdating)

        collector.cancel()
    }

    func testEmitsObservationsInOrderManually() async throws {
        let route = SimulatedLocationRouteFixtures.normalWalking()
        let provider = SimulatedLocationProvider(route: route, mode: .manual)
        let collector = ObservationCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        XCTAssertTrue(provider.isUpdating)

        for expected in route.observations {
            XCTAssertTrue(provider.advance())
            await collector.wait(forCount: collector.ids.count + 1, timeout: 1)
        }

        XCTAssertEqual(collector.ids, route.observations.map(\.id))
        XCTAssertFalse(provider.advance())
        XCTAssertFalse(provider.isUpdating)
        XCTAssertEqual(provider.remainingCount, 0)

        collector.cancel()
    }

    func testStopsEmittingAfterStop() async throws {
        let route = SimulatedLocationRouteFixtures.stationary()
        let provider = SimulatedLocationProvider(route: route, mode: .manual)
        let collector = ObservationCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        XCTAssertTrue(provider.advance())
        await collector.wait(forCount: 1, timeout: 1)

        provider.stopUpdating()
        XCTAssertEqual(provider.stopCount, 1)
        XCTAssertFalse(provider.isUpdating)
        XCTAssertFalse(provider.advance())

        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(collector.ids, ["stationary-0"])

        collector.cancel()
    }

    func testRouteCompletionDoesNotCrashAndLeavesRestartable() async throws {
        let route = SimulatedLocationRouteFixtures.poorAccuracy()
        let provider = SimulatedLocationProvider(route: route, mode: .manual)
        let collector = ObservationCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        XCTAssertTrue(provider.advance())
        await collector.wait(forCount: 1, timeout: 1)
        XCTAssertFalse(provider.advance())
        XCTAssertFalse(provider.isUpdating)

        // Restart from the beginning on the same stream.
        try await provider.startUpdating()
        XCTAssertEqual(provider.startCount, 2)
        XCTAssertEqual(provider.nextIndex, 0)
        XCTAssertTrue(provider.advance())
        await collector.wait(forCount: 2, timeout: 1)
        XCTAssertEqual(collector.ids, ["poor-accuracy-0", "poor-accuracy-0"])

        collector.cancel()
    }

    func testDoesNotCreateDuplicatePlaybackTasksOnRepeatedStart() async throws {
        var sleepCalls = 0
        let route = SimulatedLocationRouteFixtures.normalWalking()
        let provider = SimulatedLocationProvider(
            route: route,
            mode: .timed,
            sleep: { _ in
                sleepCalls += 1
            }
        )
        let collector = ObservationCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        try await provider.startUpdating()
        try await provider.startUpdating()
        XCTAssertEqual(provider.startCount, 3)

        await collector.wait(forCount: route.observations.count, timeout: 2)
        XCTAssertEqual(collector.ids, route.observations.map(\.id))
        // Timed playback sleeps between steps; only one active task should drive them.
        XCTAssertEqual(sleepCalls, route.observations.count - 1)
        XCTAssertFalse(provider.isUpdating)

        collector.cancel()
    }

    func testTimedPlaybackUsesInjectableSleepNotRealWallClock() async throws {
        var delays: [TimeInterval] = []
        let route = SimulatedLocationRouteFixtures.gapsBetweenObservations()
        let provider = SimulatedLocationProvider(
            route: route,
            mode: .timed,
            sleep: { delay in
                delays.append(delay)
            }
        )
        let collector = ObservationCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        await collector.wait(forCount: route.observations.count, timeout: 2)

        XCTAssertEqual(collector.ids, ["gap-0", "gap-1", "gap-2"])
        // First step delay is 0 (no sleep); remaining delays match fixture.
        XCTAssertEqual(delays, [120, 180])

        collector.cancel()
    }

    func testExposesConfiguredAuthorizationState() async {
        let provider = SimulatedLocationProvider(
            route: SimulatedLocationRouteFixtures.stationary(),
            authorizationState: .denied,
            mode: .manual
        )
        XCTAssertEqual(provider.authorizationState, .denied)

        let undetermined = SimulatedLocationProvider(
            route: SimulatedLocationRouteFixtures.stationary(),
            authorizationState: .notDetermined,
            mode: .manual
        )
        await undetermined.requestAuthorization(mode: .whenInUse)
        XCTAssertEqual(undetermined.authorizationState, .whenInUse)
    }

    func testFixturesCoverRepresentativeScenarios() {
        let fixtures: [SimulatedLocationRoute] = [
            SimulatedLocationRouteFixtures.stationary(),
            SimulatedLocationRouteFixtures.normalWalking(),
            SimulatedLocationRouteFixtures.drivingLike(),
            SimulatedLocationRouteFixtures.poorAccuracy(),
            SimulatedLocationRouteFixtures.staleReadings(),
            SimulatedLocationRouteFixtures.duplicates(),
            SimulatedLocationRouteFixtures.teleportJump(),
            SimulatedLocationRouteFixtures.gapsBetweenObservations(),
        ]

        let names = Set(fixtures.map(\.name))
        XCTAssertEqual(names.count, 8)
        for fixture in fixtures {
            XCTAssertFalse(fixture.observations.isEmpty, fixture.name)
            XCTAssertEqual(fixture.stepDelays.count, fixture.observations.count, fixture.name)
            XCTAssertTrue(fixture.observations.allSatisfy { $0.provider == .simulated })
        }
    }
}

// MARK: - Collectors

@MainActor
private final class ObservationCollector {
    private(set) var ids: [String] = []
    private var task: Task<Void, Never>?
    private let stream: AsyncStream<LocationObservation>

    init(stream: AsyncStream<LocationObservation>) {
        self.stream = stream
    }

    func start() async {
        let stream = self.stream
        task = Task { [weak self] in
            for await observation in stream {
                guard let self else { return }
                await MainActor.run {
                    self.ids.append(observation.id)
                }
            }
        }
        // Let the for-await subscription attach before producers run.
        await Task.yield()
    }

    func wait(forCount count: Int, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while ids.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertGreaterThanOrEqual(ids.count, count, "timed out waiting for \(count) observations")
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
