//
//  LocationSession.swift
//  Push
//
//  App-lifetime orchestration: provider → validator → inferrer → sync.
//  Owned by AppDataContainer — never by MapViewModel / presentation.
//  No Core Location, no Supabase schema, no movement throttle (later PRs).
//

import Combine
import Foundation

/// Concrete `LocationSessioning` for mock, simulated, and (later) live providers.
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

    private var observationTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var isConsuming = false
    private var isShutDown = false
    private var previousAccepted: LocationObservation?

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
        unpublishTimeout: TimeInterval = LocationPipelineConstants.unpublishBestEffortTimeout
    ) {
        self.provider = provider
        self.validator = validator
        self.inferrer = inferrer
        self.sync = sync
        self.presenceSync = sync
        self.availabilityProvider = availabilityProvider
        self.now = now
        self.unpublishTimeout = unpublishTimeout
        self.state = LocationTrackingState(
            authorization: provider.authorizationState,
            isTrackingEnabled: isTrackingDesired,
            isPresencePublishingEnabled: isPresencePublishingEnabled
        )
    }

    // MARK: - LocationSessioning

    func startIfEligible() async {
        guard !isShutDown else { return }

        state.authorization = provider.authorizationState

        // Pipeline inputs (auth + publish + not shut down). Tracking flag is
        // set true when we actually start so repeated stop/start stays safe.
        guard canRunPipeline else {
            if isConsuming {
                pauseConsumption(clearTrackingEnabled: true)
            } else {
                // Not actively tracking when auth/publish/session gates fail.
                state.isTrackingEnabled = false
            }
            return
        }

        state.isTrackingEnabled = true

        // Already consuming — avoid a second provider start / duplicate task.
        if isConsuming {
            ensureObservationTask()
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
    }

    func stop() {
        guard !isShutDown else { return }
        pauseConsumption(clearTrackingEnabled: true)
    }

    func shutdown() {
        // Idempotent: always ensure provider/tasks are stopped.
        isShutDown = true
        observationTask?.cancel()
        observationTask = nil
        syncTask?.cancel()
        syncTask = nil
        isConsuming = false
        previousAccepted = nil
        provider.stopUpdating()
        state.isTrackingEnabled = false
        state.lastObservation = nil
        state.lastAcceptedAt = nil
        state.lastUploadAt = nil
        state.lastErrorCode = nil
    }

    func unpublishBestEffort() async {
        guard !isShutDown else { return }

        let sync = self.sync
        let timeout = unpublishTimeout
        let work = Task {
            try await sync.unpublishCurrentPresence()
        }
        let timeoutTask = Task {
            let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            work.cancel()
        }
        defer { timeoutTask.cancel() }

        do {
            try await work.value
        } catch {
            // Offline / cancelled / not implemented — server expiry is the fallback.
            if !isShutDown {
                state.lastErrorCode = LocationSessionErrorCode.unpublishFailed
            }
        }
    }

    func handleLifecyclePhase(_ phase: LocationLifecyclePhase) async {
        // Phase 1: when-in-use only; no background pipeline changes yet.
        // Forwarding seam exists for ContentView / later permission work.
        _ = phase
    }

    // MARK: - Publish / auth updates (Ghost + permission seams)

    /// Orthogonal Ghost flag. Does not change availability.
    func setPresencePublishingEnabled(_ enabled: Bool) async {
        guard !isShutDown else { return }
        state.isPresencePublishingEnabled = enabled
        if enabled {
            await startIfEligible()
        } else {
            pauseConsumption(clearTrackingEnabled: false)
        }
    }

    // MARK: - Private

    /// Auth + publish + session alive. Does not require `isTrackingEnabled`
    /// so `startIfEligible` can re-enable after `stop()`.
    private var canRunPipeline: Bool {
        !isShutDown
            && state.isPresencePublishingEnabled
            && state.authorization.allowsWhenInUseUpdates
    }

    /// Stops provider updates and ignores further observations without cancelling
    /// the long-lived stream consumer (restart-safe).
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

    private func consumeObservations() async {
        for await observation in provider.observations {
            guard !Task.isCancelled, !isShutDown else { break }
            // Keep the consumer alive across stop/start; ignore while paused.
            guard isConsuming else { continue }
            process(observation)
        }
        // Stream finished or cancelled — allow a later start to re-subscribe.
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
        state.lastObservation = validated.observation
        state.lastAcceptedAt = now()
        state.authorization = provider.authorizationState

        let draft = inferrer.infer(
            from: [validated],
            manualAvailability: availabilityProvider(),
            isPublished: state.isPresencePublishingEnabled,
            previous: nil
        )

        enqueueSync(draft)
    }

    /// Fire-and-forget sync off the hot observation path so MainActor is not blocked on network.
    private func enqueueSync(_ draft: PresenceStatusDraft) {
        guard !isShutDown else { return }

        syncTask?.cancel()
        let sync = self.sync
        syncTask = Task { [weak self] in
            do {
                try await sync.upsertCurrentPresence(draft)
                await self?.recordSyncSuccess()
            } catch is CancellationError {
                return
            } catch {
                await self?.recordSyncFailure()
            }
        }
    }

    private func recordSyncSuccess() {
        guard !isShutDown else { return }
        state.lastUploadAt = now()
        state.lastErrorCode = nil
    }

    private func recordSyncFailure() {
        guard !isShutDown else { return }
        state.lastErrorCode = LocationSessionErrorCode.upsertFailed
    }
}

/// PushLog-safe codes only — never localized OS strings.
enum LocationSessionErrorCode {
    static let providerStartFailed = "location_provider_start_failed"
    static let upsertFailed = "location_upsert_failed"
    static let unpublishFailed = "location_unpublish_failed"
}
