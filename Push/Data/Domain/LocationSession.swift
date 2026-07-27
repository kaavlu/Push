//
//  LocationSession.swift
//  Push
//
//  App-lifetime: provider → validator → activity inference → draft → throttle → sync.
//  Owned by AppDataContainer — never MapViewModel. No Core Location types.
//

import Combine
import Foundation

/// Concrete `LocationSessioning` for mock, simulated, and live providers.
@MainActor
final class LocationSession: LocationSessioning {
    /// Session-owned tracking state. Setter is internal so the pipeline
    /// extension (separate file) can update fields; Views only read.
    @Published internal(set) var state: LocationTrackingState

    var statePublisher: AnyPublisher<LocationTrackingState, Never> {
        $state.eraseToAnyPublisher()
    }

    let provider: LocationProviding
    let validator: LocationObservationValidating
    let inferrer: PresenceInferring
    let activityEngine: ActivityInferenceEngine
    let sync: PresenceSyncing
    let availabilityProvider: @MainActor () -> FriendAvailabilityState?
    let now: @MainActor () -> Date
    let unpublishTimeout: TimeInterval
    let sleep: @MainActor (TimeInterval) async -> Void

    var observationTask: Task<Void, Never>?
    var syncTask: Task<Void, Never>?
    var heartbeatTask: Task<Void, Never>?
    var isConsuming = false
    var isShutDown = false
    var previousAccepted: LocationObservation?
    var lastAcceptedValidated: ValidatedObservation?
    var publishSnapshot = PresencePublishSnapshot()
    var pendingTrigger: PresenceSyncTrigger?
    var activityState = LocationSessionActivityState()

    /// Exposed for tests that need the same sync instance assertions.
    let presenceSync: PresenceSyncing

    init(
        provider: LocationProviding,
        validator: LocationObservationValidating = LocationObservationValidator(),
        inferrer: PresenceInferring = PassthroughPresenceInferrer(),
        activityEngine: ActivityInferenceEngine = DeterministicActivityInferenceEngine(),
        sync: PresenceSyncing = NoOpPresenceSync(),
        availabilityProvider: @escaping @MainActor () -> FriendAvailabilityState? = { nil },
        isPresencePublishingEnabled: Bool = true,
        isTrackingDesired: Bool = true,
        now: @escaping @MainActor () -> Date = { Date() },
        unpublishTimeout: TimeInterval = LocationPipelineConstants.unpublishBestEffortTimeout,
        sleep: (@MainActor (TimeInterval) async -> Void)? = nil
    ) {
        self.provider = provider
        self.validator = validator
        self.inferrer = inferrer
        self.activityEngine = activityEngine
        self.sync = sync
        self.presenceSync = sync
        self.availabilityProvider = availabilityProvider
        self.now = now
        self.unpublishTimeout = unpublishTimeout
        self.sleep = sleep ?? { interval in
            let ns = UInt64(max(0, interval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
        }
        self.state = LocationTrackingState(
            authorization: provider.authorizationState,
            isTrackingEnabled: isTrackingDesired,
            isPresencePublishingEnabled: isPresencePublishingEnabled
        )
        provider.setAuthorizationChangeHandler { [weak self] in
            guard let self else { return }
            Task { await self.handleAuthorizationStateChanged() }
        }
    }

    // MARK: - LocationSessioning

    func startIfEligible() async {
        guard !isShutDown else { return }

        if provider.authorizationState == .notDetermined {
            await provider.requestAuthorization(mode: .whenInUse)
        }
        state.authorization = provider.authorizationState

        guard canRunPipeline else {
            if isConsuming {
                pauseConsumption(clearTrackingEnabled: true)
            } else {
                state.isTrackingEnabled = false
            }
            stopHeartbeatLoop()
            return
        }

        state.isTrackingEnabled = true

        if isConsuming {
            ensureObservationTask()
            ensureHeartbeatLoop()
            return
        }

        do {
            try await provider.startUpdating()
        } catch {
            state.lastErrorCode = LocationSessionErrorCode.providerStartFailed
            state.isTrackingEnabled = false
            return
        }

        state.authorization = provider.authorizationState
        isConsuming = true
        ensureObservationTask()
        ensureHeartbeatLoop()
    }

    func stop() {
        guard !isShutDown else { return }
        pauseConsumption(clearTrackingEnabled: true)
        stopHeartbeatLoop()
    }

    func shutdown() {
        isShutDown = true
        observationTask?.cancel()
        observationTask = nil
        syncTask?.cancel()
        syncTask = nil
        stopHeartbeatLoop()
        isConsuming = false
        previousAccepted = nil
        lastAcceptedValidated = nil
        publishSnapshot = PresencePublishSnapshot()
        pendingTrigger = nil
        activityState.reset()
        provider.setAuthorizationChangeHandler(nil)
        provider.stopUpdating()
        provider.prepareForShutdown()
        sync.shutdown()
        state.isTrackingEnabled = false
        state.lastObservation = nil
        state.lastAcceptedAt = nil
        state.lastUploadAt = nil
        state.lastErrorCode = nil
    }

    func unpublishBestEffort() async {
        guard !isShutDown else { return }
        await performUnpublish(timeout: unpublishTimeout, recordError: true)
    }

    func handleLifecyclePhase(_ phase: LocationLifecyclePhase) async {
        // Phase 1: when-in-use only; no background pipeline changes yet.
        _ = phase
    }

    // MARK: - Publish / auth updates (Ghost + permission seams)

    /// Orthogonal Ghost. On → unpublish; off → republish last fix.
    func setPresencePublishingEnabled(_ enabled: Bool) async {
        guard !isShutDown else { return }
        let wasEnabled = state.isPresencePublishingEnabled
        state.isPresencePublishingEnabled = enabled

        if !enabled {
            pauseConsumption(clearTrackingEnabled: false)
            stopHeartbeatLoop()
            await performUnpublish(timeout: unpublishTimeout, recordError: true)
            return
        }

        if !wasEnabled || !isConsuming {
            await startIfEligible()
        }
        republishLastAcceptedIfPossible()
    }

    /// Permission restore / revoke. Unpublish only after losing prior when-in-use.
    func handleAuthorizationStateChanged() async {
        guard !isShutDown else { return }
        let previous = state.authorization
        state.authorization = provider.authorizationState
        if state.authorization.allowsWhenInUseUpdates {
            await startIfEligible()
            republishLastAcceptedIfPossible()
        } else if previous.allowsWhenInUseUpdates {
            pauseConsumption(clearTrackingEnabled: true)
            stopHeartbeatLoop()
            await performUnpublish(timeout: unpublishTimeout, recordError: true)
        }
    }

    // MARK: - Test hooks

    func checkHeartbeatDueForTesting() {
        processHeartbeatIfDue()
    }

    var publishSnapshotForTesting: PresencePublishSnapshot { publishSnapshot }

    /// Test hook — last non-unknown inferred activity held for heartbeats.
    var lastValidInferredActivityForTesting: InferredActivityResult? {
        activityState.lastValid
    }

    /// Test hook — retained observation window for inference.
    var recentActivityObservationsForTesting: [LocationObservation] {
        activityState.recentObservations
    }

    // MARK: - Private

    var canRunPipeline: Bool {
        !isShutDown
            && state.isPresencePublishingEnabled
            && state.authorization.allowsWhenInUseUpdates
    }

    func pauseConsumption(clearTrackingEnabled: Bool) {
        isConsuming = false
        provider.stopUpdating()
        if clearTrackingEnabled {
            state.isTrackingEnabled = false
        }
    }

    func ensureObservationTask() {
        if observationTask != nil { return }
        observationTask = Task { [weak self] in
            await self?.consumeObservations()
        }
    }

    func ensureHeartbeatLoop() {
        guard canRunPipeline, isConsuming else { return }
        if heartbeatTask != nil { return }
        heartbeatTask = Task { [weak self] in
            await self?.runHeartbeatLoop()
        }
    }

    func stopHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    func runHeartbeatLoop() async {
        while !Task.isCancelled, !isShutDown {
            await sleep(LocationPipelineConstants.presenceHeartbeatInterval)
            guard !Task.isCancelled, !isShutDown else { break }
            processHeartbeatIfDue()
        }
    }
}

