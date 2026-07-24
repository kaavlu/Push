//
//  LocationTestDoubles.swift
//  Push
//
//  Null / fake implementations for unit tests and later Phase 1 issues.
//  No Core Location, no network.
//

import Combine
import Foundation

// MARK: - Null provider (mock default — no GPS)

/// Never yields fixes. Authorization stays undetermined unless a test mutates it.
@MainActor
final class NullLocationProvider: LocationProviding {
    private(set) var authorizationState: LocationAuthorizationState
    private(set) var didStartUpdating = false
    private(set) var didStopUpdating = false
    private var continuation: AsyncStream<LocationObservation>.Continuation?

    var observations: AsyncStream<LocationObservation> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    init(authorizationState: LocationAuthorizationState = .notDetermined) {
        self.authorizationState = authorizationState
    }

    func requestAuthorization(mode: LocationAuthorizationRequest) async {
        _ = mode
        // Null provider never obtains OS permission.
        authorizationState = .denied
    }

    func startUpdating() async throws {
        didStartUpdating = true
    }

    func stopUpdating() {
        didStopUpdating = true
        continuation?.finish()
        continuation = nil
    }
}

// MARK: - Fake provider (scripted tests)

/// Yields observations on demand for validator / session tests.
@MainActor
final class FakeLocationProvider: LocationProviding {
    private(set) var authorizationState: LocationAuthorizationState
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var continuation: AsyncStream<LocationObservation>.Continuation?
    private var stream: AsyncStream<LocationObservation>!

    var observations: AsyncStream<LocationObservation> { stream }

    init(authorizationState: LocationAuthorizationState = .whenInUse) {
        self.authorizationState = authorizationState
        stream = AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    func requestAuthorization(mode: LocationAuthorizationRequest) async {
        _ = mode
        authorizationState = .whenInUse
    }

    func startUpdating() async throws {
        startCount += 1
    }

    func stopUpdating() {
        stopCount += 1
        // Keep the stream open so session restart can re-subscribe without
        // rebuilding the provider (matches SimulatedLocationProvider).
    }

    func emit(_ observation: LocationObservation) {
        continuation?.yield(observation)
    }

    func setAuthorization(_ state: LocationAuthorizationState) {
        authorizationState = state
    }
}

// MARK: - Fake session

@MainActor
final class FakeLocationSession: LocationSessioning {
    @Published private(set) var state: LocationTrackingState
    private(set) var startIfEligibleCount = 0
    private(set) var stopCount = 0
    private(set) var shutdownCount = 0
    private(set) var unpublishCount = 0
    private(set) var lastLifecyclePhase: LocationLifecyclePhase?
    /// When true, `unpublishBestEffort` delays briefly so tests can observe ordering.
    var unpublishDelayNanoseconds: UInt64 = 0
    private var isShutDown = false

    var statePublisher: AnyPublisher<LocationTrackingState, Never> {
        $state.eraseToAnyPublisher()
    }

    init(state: LocationTrackingState = LocationTrackingState()) {
        self.state = state
    }

    func startIfEligible() async {
        startIfEligibleCount += 1
        guard !isShutDown else { return }
        if state.isEligibleToPublish {
            state.isTrackingEnabled = true
        }
    }

    func stop() {
        stopCount += 1
        state.isTrackingEnabled = false
    }

    func shutdown() {
        shutdownCount += 1
        isShutDown = true
        state.isTrackingEnabled = false
        state.lastObservation = nil
        state.lastAcceptedAt = nil
        state.lastUploadAt = nil
    }

    func unpublishBestEffort() async {
        unpublishCount += 1
        if unpublishDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: unpublishDelayNanoseconds)
        }
    }

    func handleLifecyclePhase(_ phase: LocationLifecyclePhase) async {
        lastLifecyclePhase = phase
    }

    func setPresencePublishingEnabled(_ enabled: Bool) {
        state.isPresencePublishingEnabled = enabled
    }

    func setAuthorization(_ authorization: LocationAuthorizationState) {
        state.authorization = authorization
    }

    func setTrackingEnabled(_ enabled: Bool) {
        state.isTrackingEnabled = enabled
    }
}

// MARK: - Validator / inferrer / sync fakes

/// Accepts every observation as high confidence (tests that need a no-op gate).
struct AcceptAllLocationValidator: LocationObservationValidating {
    func accept(
        _ observation: LocationObservation,
        previous: LocationObservation?
    ) -> ValidatedObservation? {
        _ = previous
        return ValidatedObservation(observation: observation, confidence: .high)
    }
}

/// Rejects every observation (negative path for session tests).
struct RejectAllLocationValidator: LocationObservationValidating {
    func accept(
        _ observation: LocationObservation,
        previous: LocationObservation?
    ) -> ValidatedObservation? {
        _ = observation
        _ = previous
        return nil
    }
}

/// Builds a minimal draft from the latest history entry — Phase 1 shape, no ML.
struct PassthroughPresenceInferrer: PresenceInferring {
    func infer(
        from history: [ValidatedObservation],
        manualAvailability: FriendAvailabilityState?,
        isPublished: Bool,
        previous: PresenceStatus?
    ) -> PresenceStatusDraft {
        let latest = history.last
        let availability = manualAvailability
            ?? previous?.availability
            ?? .maybeDown
        let observation = latest?.observation
        let (vagueLat, vagueLng) = Self.vaguePair(
            latitude: observation?.latitude,
            longitude: observation?.longitude
        )
        return PresenceStatusDraft(
            availability: availability,
            isPublished: isPublished,
            activity: previous?.activity
                ?? PresenceActivity(name: "Nearby", symbolName: "location.fill"),
            placeID: previous?.placeID,
            statusNote: previous?.statusNote,
            latitude: observation?.latitude,
            longitude: observation?.longitude,
            vagueLatitude: vagueLat,
            vagueLongitude: vagueLng,
            confidence: latest?.confidence ?? .medium,
            observedAt: observation?.recordedAt ?? Date(),
            source: .location
        )
    }

    /// Phase 1 default: round exact coords to ~0.01° when writing vague pair.
    private static func vaguePair(
        latitude: Double?,
        longitude: Double?
    ) -> (Double?, Double?) {
        guard let latitude, let longitude else { return (nil, nil) }
        let q = LocationPipelineConstants.vagueCoordinateQuantumDegrees
        return ((latitude / q).rounded() * q, (longitude / q).rounded() * q)
    }
}

/// Records upserts for assertions. Thread-safe for non-MainActor sync tests.
final class FakePresenceSync: PresenceSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var _drafts: [PresenceStatusDraft] = []
    private var _flushCount = 0
    private var _unpublishCount = 0
    private var _shutdownCount = 0
    private var _isShutDown = false
    var errorToThrow: Error?
    var unpublishErrorToThrow: Error?
    /// Optional delay so session cancellation/timeout tests can race.
    var upsertDelayNanoseconds: UInt64 = 0

    var drafts: [PresenceStatusDraft] {
        lock.lock()
        defer { lock.unlock() }
        return _drafts
    }

    var flushCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _flushCount
    }

    var unpublishCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _unpublishCount
    }

    var shutdownCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _shutdownCount
    }

    var isShutDown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isShutDown
    }

    func upsertCurrentPresence(_ draft: PresenceStatusDraft) async throws {
        if upsertDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: upsertDelayNanoseconds)
        }
        lock.lock()
        let shutDown = _isShutDown
        lock.unlock()
        if shutDown { return }
        if let errorToThrow { throw errorToThrow }
        lock.lock()
        _drafts.append(draft)
        lock.unlock()
    }

    func unpublishCurrentPresence() async throws {
        lock.lock()
        let shutDown = _isShutDown
        lock.unlock()
        if shutDown { return }
        if let unpublishErrorToThrow { throw unpublishErrorToThrow }
        lock.lock()
        _unpublishCount += 1
        lock.unlock()
    }

    func flushPending() async throws {
        lock.lock()
        let shutDown = _isShutDown
        lock.unlock()
        if shutDown { return }
        if let errorToThrow { throw errorToThrow }
        lock.lock()
        _flushCount += 1
        lock.unlock()
    }

    func shutdown() {
        lock.lock()
        _isShutDown = true
        _shutdownCount += 1
        lock.unlock()
    }
}

/// Phase 1 default when live presence writes are not wired (mock / null provider).
final class NoOpPresenceSync: PresenceSyncing, @unchecked Sendable {
    func upsertCurrentPresence(_ draft: PresenceStatusDraft) async throws {
        _ = draft
    }

    func unpublishCurrentPresence() async throws {}

    func flushPending() async throws {}

    func shutdown() {}
}
