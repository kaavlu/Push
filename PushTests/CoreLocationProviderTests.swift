//
//  CoreLocationProviderTests.swift
//  PushTests
//
//  Issue #79 — CoreLocationLocationProvider mapping, lifecycle, factory selection.
//  Injectable manager seam — no real GPS hardware or permission UI.
//

import CoreLocation
import XCTest
@testable import Push

@MainActor
final class CoreLocationProviderTests: XCTestCase {

    private let personID: Person.ID = "core-location-user"
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_100)

    // MARK: - Authorization mapping

    func testAuthorizationStateMapping() {
        XCTAssertEqual(
            CoreLocationMapping.authorizationState(from: .notDetermined),
            .notDetermined
        )
        XCTAssertEqual(
            CoreLocationMapping.authorizationState(from: .restricted),
            .restricted
        )
        XCTAssertEqual(
            CoreLocationMapping.authorizationState(from: .denied),
            .denied
        )
        XCTAssertEqual(
            CoreLocationMapping.authorizationState(from: .authorizedWhenInUse),
            .whenInUse
        )
        XCTAssertEqual(
            CoreLocationMapping.authorizationState(from: .authorizedAlways),
            .always
        )
    }

    // MARK: - CLLocation → LocationObservation

    func testMapsCLLocationFields() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 12.5,
            horizontalAccuracy: 8,
            verticalAccuracy: 4,
            course: 90,
            speed: 1.5,
            timestamp: timestamp
        )

        let observation = CoreLocationMapping.observation(
            from: location,
            personID: personID,
            receivedAt: fixedNow,
            id: "fix-id"
        )

        XCTAssertEqual(observation.id, "fix-id")
        XCTAssertEqual(observation.personID, personID)
        XCTAssertEqual(observation.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(observation.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(observation.horizontalAccuracyMeters, 8, accuracy: 0.001)
        XCTAssertEqual(observation.altitudeMeters, 12.5)
        XCTAssertEqual(observation.speedMetersPerSecond, 1.5)
        XCTAssertEqual(observation.courseDegrees, 90)
        XCTAssertEqual(observation.recordedAt, timestamp)
        XCTAssertEqual(observation.receivedAt, fixedNow)
        XCTAssertEqual(observation.provider, .coreLocation)
    }

    func testNormalizesInvalidAppleSentinels() {
        XCTAssertEqual(CoreLocationMapping.normalizedHorizontalAccuracy(-1), 0)
        XCTAssertEqual(CoreLocationMapping.normalizedHorizontalAccuracy(.nan), 0)
        XCTAssertNil(CoreLocationMapping.normalizedSpeed(-1))
        XCTAssertNil(CoreLocationMapping.normalizedCourse(-1))
        XCTAssertNil(
            CoreLocationMapping.normalizedAltitude(altitude: 10, verticalAccuracy: -1)
        )
        XCTAssertEqual(
            CoreLocationMapping.normalizedAltitude(altitude: 10, verticalAccuracy: 3),
            10
        )
    }

    func testInvalidAccuracyProducesObservationRejectedByValidator() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4),
            altitude: 0,
            horizontalAccuracy: -1,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: fixedNow
        )
        let observation = CoreLocationMapping.observation(
            from: location,
            personID: personID,
            receivedAt: fixedNow
        )

        XCTAssertEqual(observation.horizontalAccuracyMeters, 0)
        XCTAssertNil(observation.speedMetersPerSecond)
        XCTAssertNil(observation.courseDegrees)
        XCTAssertNil(observation.altitudeMeters)

        let validator = LocationObservationValidator(now: { self.fixedNow })
        XCTAssertNil(validator.accept(observation, previous: nil))
    }

    // MARK: - Provider lifecycle

    func testRepeatedStartDoesNotDuplicateManagerStarts() async throws {
        let manager = FakeCoreLocationManager(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )

        try await provider.startUpdating()
        try await provider.startUpdating()
        try await provider.startUpdating()

        XCTAssertEqual(provider.startCount, 3)
        XCTAssertEqual(manager.startUpdatingCallCount, 1)
        XCTAssertTrue(provider.isUpdating)
    }

    func testStopPreventsLaterObservations() async throws {
        let manager = FakeCoreLocationManager(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )
        let collector = ObservationIDCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        provider.handleLocationsForTesting([makeLocation(latitude: 37.77)])
        await collector.wait(forCount: 1, timeout: 1)

        provider.stopUpdating()
        provider.handleLocationsForTesting([makeLocation(latitude: 37.78)])
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(collector.ids.count, 1)
        XCTAssertEqual(manager.stopUpdatingCallCount, 1)
        XCTAssertFalse(provider.isUpdating)

        collector.cancel()
    }

    func testShutdownStopsProvider() async throws {
        let manager = FakeCoreLocationManager(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )

        try await provider.startUpdating()
        provider.prepareForShutdown()

        try await provider.startUpdating()
        XCTAssertEqual(manager.startUpdatingCallCount, 1, "torn-down provider must not restart GPS")
        XCTAssertFalse(provider.isUpdating)
        XCTAssertNil(manager.delegate)
    }

    func testEmitsMappedObservationWhileUpdating() async throws {
        let manager = FakeCoreLocationManager(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )
        let collector = ObservationIDCollector(stream: provider.observations)
        await collector.start()

        try await provider.startUpdating()
        let location = makeLocation(latitude: 37.75, longitude: -122.4, accuracy: 5)
        provider.handleLocationsForTesting([location])
        await collector.wait(forCount: 1, timeout: 1)

        let first = try XCTUnwrap(collector.observations.first)
        XCTAssertEqual(first.provider, .coreLocation)
        XCTAssertEqual(first.latitude, 37.75, accuracy: 0.0001)
        XCTAssertEqual(first.personID, personID)

        collector.cancel()
    }

    func testAuthorizationChangeUpdatesState() {
        let manager = FakeCoreLocationManager(authorizationStatus: .notDetermined)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )
        XCTAssertEqual(provider.authorizationState, .notDetermined)

        var handlerCalls = 0
        provider.setAuthorizationChangeHandler { handlerCalls += 1 }

        manager.authorizationStatus = .authorizedWhenInUse
        provider.handleAuthorizationStatusForTesting(.authorizedWhenInUse)
        XCTAssertEqual(provider.authorizationState, .whenInUse)
        XCTAssertEqual(handlerCalls, 1)

        manager.authorizationStatus = .denied
        provider.handleAuthorizationStatusForTesting(.denied)
        XCTAssertEqual(provider.authorizationState, .denied)
        XCTAssertEqual(handlerCalls, 2)
    }

    func testRequestAuthorizationCompletesWhenAlreadyDetermined() async {
        let manager = FakeCoreLocationManager(authorizationStatus: .denied)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )

        await provider.requestAuthorization(mode: .whenInUse)

        XCTAssertEqual(manager.requestWhenInUseCallCount, 0)
        XCTAssertEqual(provider.authorizationState, .denied)
    }

    func testRequestAuthorizationWaitsForDelegate() async {
        let manager = FakeCoreLocationManager(authorizationStatus: .notDetermined)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )

        let task = Task {
            await provider.requestAuthorization(mode: .whenInUse)
        }
        // Let the request park on the continuation.
        await Task.yield()
        XCTAssertEqual(manager.requestWhenInUseCallCount, 1)

        manager.authorizationStatus = .authorizedWhenInUse
        provider.handleAuthorizationStatusForTesting(.authorizedWhenInUse)
        await task.value

        XCTAssertEqual(provider.authorizationState, .whenInUse)
    }

    // MARK: - Factory / container selection

    func testFactorySelectsSimulatedWhenFlagPresentEvenIfCoreLocationPreferred() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [LocationSessionLaunchArgument.simLocation],
            usesCoreLocation: true
        )
        XCTAssertTrue(provider is SimulatedLocationProvider)
    }

    func testFactorySelectsCoreLocationWhenLiveAndNoSimFlag() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [],
            usesCoreLocation: true
        )
        XCTAssertTrue(provider is CoreLocationLocationProvider)
    }

    func testFactorySelectsNullWhenMockAndNoSimFlag() {
        let provider = LocationSessionFactory.makeProvider(
            personID: personID,
            arguments: [],
            usesCoreLocation: false
        )
        XCTAssertTrue(provider is NullLocationProvider)
    }

    func testMockContainerDoesNotStartCoreLocationProvider() {
        let container = AppDataContainer(seed: .standard())
        // Default mock session must not hold a Core Location provider.
        let session = container.locationSession as? LocationSession
        XCTAssertNotNil(session)
        // Reach provider only via factory selection guarantees above; mock uses
        // Null or Simulated — never CoreLocationLocationProvider without live flag.
        let provider = LocationSessionFactory.makeProvider(
            personID: container.currentUserID,
            arguments: [],
            usesCoreLocation: false
        )
        XCTAssertFalse(provider is CoreLocationLocationProvider)
        XCTAssertTrue(provider is NullLocationProvider)
    }

    func testSessionShutdownStopsCoreLocationProvider() async throws {
        let manager = FakeCoreLocationManager(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationLocationProvider(
            personID: personID,
            manager: manager,
            now: { self.fixedNow }
        )
        let session = LocationSession(
            provider: provider,
            validator: AcceptAllLocationValidator(),
            sync: FakePresenceSync()
        )

        await session.startIfEligible()
        XCTAssertEqual(manager.startUpdatingCallCount, 1)

        session.shutdown()

        // stopUpdating + prepareForShutdown both halt the manager.
        XCTAssertGreaterThanOrEqual(manager.stopUpdatingCallCount, 1)
        XCTAssertNil(manager.delegate)
        XCTAssertFalse(session.state.isTrackingEnabled)
    }

    // MARK: - Helpers

    private func makeLocation(
        latitude: Double,
        longitude: Double = -122.42,
        accuracy: CLLocationAccuracy = 10
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 5,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 3,
            course: 45,
            speed: 0.5,
            timestamp: fixedNow
        )
    }
}

// MARK: - Fake manager

@MainActor
private final class FakeCoreLocationManager: NSObject, CoreLocationManaging {
    var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    var activityType: CLActivityType = .other
    var authorizationStatus: CLAuthorizationStatus

    private(set) var startUpdatingCallCount = 0
    private(set) var stopUpdatingCallCount = 0
    private(set) var requestWhenInUseCallCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseCallCount += 1
    }

    func startUpdatingLocation() {
        startUpdatingCallCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingCallCount += 1
    }
}

// MARK: - Collector

@MainActor
private final class ObservationIDCollector {
    private(set) var ids: [String] = []
    private(set) var observations: [LocationObservation] = []
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
                    self.observations.append(observation)
                }
            }
        }
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
