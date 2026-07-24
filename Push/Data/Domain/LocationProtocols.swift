//
//  LocationProtocols.swift
//  Push
//
//  Injectable seams for location collection, session lifetime, validation,
//  draft building, and presence upload. Implementations land in later PRs.
//

import Combine
import Foundation

// MARK: - Location (device edge)

/// Device / simulated location source. Core Location types stay inside the
/// infrastructure provider only — this protocol exposes app-owned observations.
@MainActor
protocol LocationProviding: AnyObject {
    var authorizationState: LocationAuthorizationState { get }
    var observations: AsyncStream<LocationObservation> { get }
    func requestAuthorization(mode: LocationAuthorizationRequest) async
    func startUpdating() async throws
    func stopUpdating()
    /// Invoked on MainActor when OS authorization changes (Core Location only).
    func setAuthorizationChangeHandler(_ handler: (@MainActor () -> Void)?)
    /// Final teardown (drop manager delegate, refuse further starts). Idempotent.
    func prepareForShutdown()
}

extension LocationProviding {
    func setAuthorizationChangeHandler(_ handler: (@MainActor () -> Void)?) {
        _ = handler
    }

    func prepareForShutdown() {}
}

// MARK: - Session (app lifetime)

/// App-lifetime owner of tracking state. Retained by prepared `AppDataContainer`
/// — not by `MapViewModel`.
@MainActor
protocol LocationSessioning: AnyObject {
    var state: LocationTrackingState { get }
    var statePublisher: AnyPublisher<LocationTrackingState, Never> { get }
    /// Starts GPS consumption when signed-in, authorized, and presence publishing enabled.
    func startIfEligible() async
    func stop()
    /// Explicit teardown: stop provider, cancel upload tasks, drop streams. Idempotent.
    /// Does not itself guarantee server unpublish — see `unpublishBestEffort()`.
    func shutdown()
    /// Best-effort presence unpublish (short timeout). Does not throw; safe offline.
    /// Call while auth JWT may still be valid, before `shutdown()`.
    func unpublishBestEffort() async
    func handleLifecyclePhase(_ phase: LocationLifecyclePhase) async
    /// Orthogonal Ghost control. `true` = publishing (Ghost off). Does not change availability.
    func setPresencePublishingEnabled(_ enabled: Bool) async
}

// MARK: - Validation

/// Pure accuracy / age / teleport gate. Implementations are Sendable and free of I/O.
protocol LocationObservationValidating: Sendable {
    func accept(
        _ observation: LocationObservation,
        previous: LocationObservation?
    ) -> ValidatedObservation?
}

// MARK: - Draft building

/// Phase 1: mirrored availability + synthetic place; no venue/ML.
protocol PresenceInferring: Sendable {
    func infer(
        from history: [ValidatedObservation],
        manualAvailability: FriendAvailabilityState?,
        isPublished: Bool,
        previous: PresenceStatus?
    ) -> PresenceStatusDraft
}

// MARK: - Sync

/// Network/upload edge for current presence. Must not require MainActor execution.
protocol PresenceSyncing: AnyObject, Sendable {
    func upsertCurrentPresence(_ draft: PresenceStatusDraft) async throws
    /// Clear friend-visible presence (Ghost / sign-out / permission loss).
    /// Implementations may no-op until live write lands.
    func unpublishCurrentPresence() async throws
    /// Retry the newest buffered draft after a failed write (no-op when empty).
    func flushPending() async throws
    /// Stop retries and reject future writes. Idempotent.
    func shutdown()
}

extension PresenceSyncing {
    func shutdown() {}
}
