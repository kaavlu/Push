//
//  CoreLocationLocationProvider.swift
//  Push
//
//  Production Apple location provider behind `LocationProviding`.
//  Owns CLLocationManager; maps into app-owned observations only.
//  No validation, throttle, sync, or map updates.
//

import CoreLocation
import Foundation

// MARK: - Injectable manager seam (tests use a fake; production uses CLLocationManager)

/// Narrow surface over `CLLocationManager` so unit tests never need real GPS.
@MainActor
protocol CoreLocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var activityType: CLActivityType { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: CoreLocationManaging {}

// MARK: - Provider

/// Foreground when-in-use location source for live builds (not mock, not `--sim-location`).
///
/// Lifecycle:
/// - One long-lived `AsyncStream` (restart-safe; stop does not finish the stream).
/// - Repeated `startUpdating()` / `stopUpdating()` are safe (no duplicate managers).
/// - Does not validate, throttle, or write presence.
@MainActor
final class CoreLocationLocationProvider: NSObject, LocationProviding {
    private(set) var authorizationState: LocationAuthorizationState
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isUpdating = false

    private let personID: Person.ID
    private let manager: CoreLocationManaging
    private let now: () -> Date

    private var continuation: AsyncStream<LocationObservation>.Continuation?
    private var stream: AsyncStream<LocationObservation>!
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var authorizationChangeHandler: (@MainActor () -> Void)?
    private var isTornDown = false

    var observations: AsyncStream<LocationObservation> { stream }

    init(
        personID: Person.ID,
        manager: CoreLocationManaging? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.personID = personID
        self.now = now
        let resolved = manager ?? CLLocationManager()
        self.manager = resolved
        self.authorizationState = CoreLocationMapping.authorizationState(
            from: resolved.authorizationStatus
        )
        super.init()
        stream = AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
        configureManager()
    }

    // MARK: - LocationProviding

    func requestAuthorization(mode: LocationAuthorizationRequest) async {
        guard !isTornDown else { return }
        guard mode == .whenInUse else { return }

        syncAuthorizationFromManager()
        guard authorizationState == .notDetermined else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // If a prior request is still waiting, complete it first so callers don't hang.
            authorizationContinuation?.resume()
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdating() async throws {
        guard !isTornDown else { return }
        startCount += 1
        syncAuthorizationFromManager()

        guard authorizationState.allowsWhenInUseUpdates else {
            isUpdating = false
            return
        }

        // Idempotent: already running → leave manager as-is.
        if isUpdating { return }

        isUpdating = true
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        stopCount += 1
        isUpdating = false
        // Safe even when not started; stream stays open for restart.
        manager.stopUpdatingLocation()
    }

    func setAuthorizationChangeHandler(_ handler: (@MainActor () -> Void)?) {
        authorizationChangeHandler = handler
    }

    /// Session shutdown: drop the manager delegate and refuse further starts.
    func prepareForShutdown() {
        isTornDown = true
        isUpdating = false
        manager.stopUpdatingLocation()
        manager.delegate = nil
        finishAuthorizationWait()
        // Keep stream open; session owns subscription lifecycle.
    }

    // MARK: - Test hooks

    /// Delivers a manager location callback without real GPS (tests / fake manager).
    func handleLocationsForTesting(_ locations: [CLLocation]) {
        processLocations(locations)
    }

    /// Simulates an authorization delegate callback.
    func handleAuthorizationStatusForTesting(_ status: CLAuthorizationStatus) {
        applyAuthorizationStatus(status)
    }

    // MARK: - Private

    private func configureManager() {
        manager.desiredAccuracy = CoreLocationProviderConstants.desiredAccuracy
        manager.distanceFilter = CoreLocationProviderConstants.distanceFilterMeters
        manager.activityType = CoreLocationProviderConstants.activityType
        manager.delegate = self
    }

    private func syncAuthorizationFromManager() {
        authorizationState = CoreLocationMapping.authorizationState(
            from: manager.authorizationStatus
        )
    }

    private func applyAuthorizationStatus(_ status: CLAuthorizationStatus) {
        let previous = authorizationState
        authorizationState = CoreLocationMapping.authorizationState(from: status)
        finishAuthorizationWait()

        if authorizationState != previous {
            authorizationChangeHandler?()
        }

        // Permission lost while updating → stop hardware; session handles unpublish.
        if isUpdating, !authorizationState.allowsWhenInUseUpdates {
            isUpdating = false
            manager.stopUpdatingLocation()
        }
    }

    private func finishAuthorizationWait() {
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }

    private func processLocations(_ locations: [CLLocation]) {
        guard !isTornDown, isUpdating else { return }
        guard let continuation else { return }

        for location in locations {
            let observation = CoreLocationMapping.observation(
                from: location,
                personID: personID,
                receivedAt: now()
            )
            // Never log coordinates or raw Apple location objects.
            continuation.yield(observation)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.applyAuthorizationStatus(status)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            self.processLocations(locations)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Failures are non-fatal: keep the stream open, do not crash.
        // Never log coordinates or localized OS error strings (PII risk).
        _ = error
        PushLog.network.error(
            "core_location_provider_failed code=\(PushLog.safeDescription(for: error), privacy: .public)"
        )
    }
}
