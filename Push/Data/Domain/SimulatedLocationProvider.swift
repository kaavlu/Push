//
//  SimulatedLocationProvider.swift
//  Push
//
//  Deterministic scripted location source for tests and DEBUG dogfooding.
//  No Core Location, no network.
//

import Foundation

/// How scripted observations are advanced.
enum SimulatedPlaybackMode: Equatable, Sendable {
    /// Tests call `advance()` to emit the next observation.
    case manual
    /// Emits using `stepDelays` via an injectable sleep (no real wall-clock required).
    case timed
}

/// Plays a `SimulatedLocationRoute` through `LocationProviding`.
///
/// Lifecycle:
/// - Does not emit before `startUpdating()`.
/// - `stopUpdating()` cancels playback and prevents further emissions.
/// - Restarting resets the route to the first step on the same long-lived stream.
/// - Completing a route stops updating without finishing the stream (restart-safe).
@MainActor
final class SimulatedLocationProvider: LocationProviding {
    private(set) var authorizationState: LocationAuthorizationState
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isUpdating = false
    private(set) var nextIndex = 0

    private let route: SimulatedLocationRoute
    private let mode: SimulatedPlaybackMode
    private let sleep: @MainActor @Sendable (TimeInterval) async -> Void

    private var continuation: AsyncStream<LocationObservation>.Continuation?
    private var stream: AsyncStream<LocationObservation>!
    private var playbackTask: Task<Void, Never>?

    var observations: AsyncStream<LocationObservation> { stream }

    var remainingCount: Int {
        max(0, route.observations.count - nextIndex)
    }

    init(
        route: SimulatedLocationRoute,
        authorizationState: LocationAuthorizationState = .whenInUse,
        mode: SimulatedPlaybackMode = .manual,
        sleep: @escaping @MainActor @Sendable (TimeInterval) async -> Void = { duration in
            let nanoseconds = UInt64(max(0, duration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.route = route
        self.authorizationState = authorizationState
        self.mode = mode
        self.sleep = sleep
        stream = AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    func requestAuthorization(mode: LocationAuthorizationRequest) async {
        _ = mode
        if authorizationState == .notDetermined {
            authorizationState = .whenInUse
        }
    }

    func startUpdating() async throws {
        startCount += 1
        cancelPlaybackTask()
        nextIndex = 0
        isUpdating = true

        guard mode == .timed else { return }
        playbackTask = Task { [weak self] in
            await self?.runTimedPlayback()
        }
    }

    func stopUpdating() {
        stopCount += 1
        isUpdating = false
        cancelPlaybackTask()
        // Stream stays open so restart can emit without re-subscribing.
    }

    /// Manual mode: yield the next observation. Returns `false` when not updating
    /// or the route has no remaining steps.
    @discardableResult
    func advance() -> Bool {
        guard mode == .manual else { return false }
        return yieldNextIfPossible()
    }

    // MARK: - Private

    private func cancelPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = nil
    }

    private func runTimedPlayback() async {
        while !Task.isCancelled {
            guard isUpdating else { return }
            guard nextIndex < route.observations.count else {
                isUpdating = false
                return
            }

            let delay = route.delayBeforeStep(at: nextIndex)
            if delay > 0 {
                await sleep(delay)
                guard !Task.isCancelled, isUpdating else { return }
            }

            _ = yieldNextIfPossible()
        }
    }

    @discardableResult
    private func yieldNextIfPossible() -> Bool {
        guard isUpdating else { return false }
        guard nextIndex < route.observations.count else {
            isUpdating = false
            return false
        }
        guard let continuation else { return false }

        let observation = route.observations[nextIndex]
        nextIndex += 1
        continuation.yield(observation)

        if nextIndex >= route.observations.count {
            isUpdating = false
            cancelPlaybackTask()
        }
        return true
    }
}
