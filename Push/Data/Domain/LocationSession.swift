//
//  LocationSession.swift
//  Push
//
//  App-lifetime: provider → validator → inferrer → throttle → sync.
//  Owned by AppDataContainer — never MapViewModel. No Core Location types.
//

import Combine
import Foundation

/// Concrete `LocationSessioning` for mock, simulated, and live providers.
@MainActor
final class LocationSession: LocationSessioning {
    @Published private(set) var state: LocationTrackingState

    var statePublisher: AnyPublisher<LocationTrackingState, Never> {
        $state.eraseToAnyPublisher()
    }

    private let provider: LocationProviding
    private let validator: LocationObservationValidating
    private let inferrer: PresenceInferring
    private let sync: PresenceSyncing
    private let availabilityProvider: @MainActor () -> FriendAvailabilityState?
    private let now: @MainActor () -> Date
    private let unpublishTimeout: TimeInterval
    private let sleep: @MainActor (TimeInterval) async -> Void

    private var observationTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var isConsuming = false
    private var isShutDown = false
    private var previousAccepted: LocationObservation?
    private var lastAcceptedValidated: ValidatedObservation?
    private var publishSnapshot = PresencePublishSnapshot()
    private var pendingTrigger: PresenceSyncTrigger?

    /// Exposed for tests that need the same sync instance assertions.
    let presenceSync: PresenceSyncing

    init(
        provider: LocationProviding,
        validator: LocationObservationValidating = LocationObservationValidator(),
        inferrer: PresenceInferring = PassthroughPresenceInferrer(),
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

    // MARK: - Private

    private var canRunPipeline: Bool {
        !isShutDown
            && state.isPresencePublishingEnabled
            && state.authorization.allowsWhenInUseUpdates
    }

    private func pauseConsumption(clearTrackingEnabled: Bool) {
        isConsuming = false
        provider.stopUpdating()
        if clearTrackingEnabled {
            state.isTrackingEnabled = false
        }
    }

    private func ensureObservationTask() {
        if observationTask != nil { return }
        observationTask = Task { [weak self] in
            await self?.consumeObservations()
        }
    }

    private func ensureHeartbeatLoop() {
        guard canRunPipeline, isConsuming else { return }
        if heartbeatTask != nil { return }
        heartbeatTask = Task { [weak self] in
            await self?.runHeartbeatLoop()
        }
    }

    private func stopHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func runHeartbeatLoop() async {
        while !Task.isCancelled, !isShutDown {
            await sleep(LocationPipelineConstants.presenceHeartbeatInterval)
            guard !Task.isCancelled, !isShutDown else { break }
            processHeartbeatIfDue()
        }
    }

    private func consumeObservations() async {
        for await observation in provider.observations {
            guard !Task.isCancelled, !isShutDown else { break }
            guard isConsuming else { continue }
            process(observation)
        }
        if !isShutDown {
            observationTask = nil
        }
    }

    private func process(_ observation: LocationObservation) {
        guard !isShutDown, isConsuming else { return }
        guard state.isPresencePublishingEnabled else { return }

        guard let validated = validator.accept(observation, previous: previousAccepted) else {
            return
        }

        previousAccepted = validated.observation
        lastAcceptedValidated = validated
        state.lastObservation = validated.observation
        state.lastAcceptedAt = now()
        state.authorization = provider.authorizationState

        if case .publish = PresencePublishPolicy.decisionForHeartbeat(
            now: now(), snapshot: publishSnapshot
        ) {
            enqueueDraft(from: validated, trigger: .heartbeat)
            return
        }

        let movement = PresencePublishPolicy.decisionForMovement(
            observation: validated.observation,
            now: now(),
            snapshot: publishSnapshot
        )
        guard case .publish(let trigger) = movement else { return }
        enqueueDraft(from: validated, trigger: trigger)
    }

    private func processHeartbeatIfDue() {
        guard !isShutDown else { return }
        guard state.isPresencePublishingEnabled, isConsuming else { return }
        guard case .publish = PresencePublishPolicy.decisionForHeartbeat(
            now: now(), snapshot: publishSnapshot
        ) else { return }
        guard let validated = lastAcceptedValidated else { return }
        enqueueDraft(from: validated, trigger: .heartbeat)
    }

    private func republishLastAcceptedIfPossible() {
        guard !isShutDown, state.isPresencePublishingEnabled else { return }
        guard canRunPipeline else { return }
        guard let validated = lastAcceptedValidated else { return }
        enqueueDraft(from: validated, trigger: .republish)
    }

    private func enqueueDraft(
        from validated: ValidatedObservation,
        trigger: PresenceSyncTrigger
    ) {
        let draft = inferrer.infer(
            from: [validated],
            manualAvailability: mirroredAvailability(),
            isPublished: state.isPresencePublishingEnabled,
            previous: nil
        )
        enqueueSync(draft, trigger: trigger)
    }

    private func mirroredAvailability() -> FriendAvailabilityState? {
        let value = availabilityProvider()
        if value == .ghost { return .maybeDown }
        return value
    }

    private func enqueueSync(_ draft: PresenceStatusDraft, trigger: PresenceSyncTrigger) {
        guard !isShutDown else { return }
        guard draft.isPublished else { return }

        pendingTrigger = trigger
        syncTask?.cancel()
        let sync = self.sync
        syncTask = Task { [weak self] in
            do {
                try await sync.upsertCurrentPresence(draft)
                await self?.recordSyncSuccess(draft: draft)
            } catch is CancellationError {
                return
            } catch {
                await self?.recordSyncFailure()
            }
        }
    }

    private func recordSyncSuccess(draft: PresenceStatusDraft) {
        guard !isShutDown else { return }
        let at = now()
        state.lastUploadAt = at
        state.lastErrorCode = nil
        publishSnapshot = PresencePublishPolicy.recordingSuccessfulWrite(
            on: publishSnapshot,
            at: at,
            latitude: draft.latitude,
            longitude: draft.longitude
        )
        pendingTrigger = nil
    }

    private func recordSyncFailure() {
        guard !isShutDown else { return }
        state.lastErrorCode = LocationSessionErrorCode.upsertFailed
        pendingTrigger = nil
    }

    private func performUnpublish(timeout: TimeInterval, recordError: Bool) async {
        syncTask?.cancel()
        syncTask = nil
        pendingTrigger = nil
        publishSnapshot = PresencePublishPolicy.recordingUnpublish(on: publishSnapshot)

        let sync = self.sync
        let work = Task { try await sync.unpublishCurrentPresence() }
        let timeoutTask = Task {
            let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            work.cancel()
        }
        defer { timeoutTask.cancel() }

        do {
            try await work.value
            if !isShutDown { state.lastErrorCode = nil }
        } catch {
            if recordError, !isShutDown {
                state.lastErrorCode = LocationSessionErrorCode.unpublishFailed
            }
        }
    }
}


