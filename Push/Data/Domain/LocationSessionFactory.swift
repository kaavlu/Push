//
//  LocationSessionFactory.swift
//  Push
//
//  Builds app-lifetime LocationSession instances for mock / DEBUG sim / live.
//  Provider selection: sim flag → Simulated; live → Core Location; mock → Null.
//

import Foundation

enum LocationSessionLaunchArgument {
    /// DEBUG dogfood: scripted `SimulatedLocationProvider` instead of Core Location / null.
    static let simLocation = "--sim-location"
    /// DEBUG dogfood: 20s stationary heartbeat instead of 15m (Issue #76).
    static let fastPresenceHeartbeat = "--fast-presence-heartbeat"
}

enum LocationSessionFactory {
    /// Default session for a container.
    /// - Mock: Null (or Simulated with `--sim-location`).
    /// - Live: Core Location (or Simulated with `--sim-location`).
    @MainActor
    static func makeDefault(
        personID: Person.ID,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        usesCoreLocation: Bool = false,
        availabilityProvider: @escaping @MainActor () -> FriendAvailabilityState? = { nil },
        sync: PresenceSyncing = NoOpPresenceSync()
    ) -> LocationSession {
        let provider = makeProvider(
            personID: personID,
            arguments: arguments,
            usesCoreLocation: usesCoreLocation
        )
        return LocationSession(
            provider: provider,
            validator: LocationObservationValidator(),
            inferrer: PassthroughPresenceInferrer(),
            activityEngine: DeterministicActivityInferenceEngine(),
            sync: sync,
            availabilityProvider: availabilityProvider,
            isPresencePublishingEnabled: true,
            // Authenticated container intends tracking; provider auth still gates start.
            isTrackingDesired: true
        )
    }

    @MainActor
    static func makeProvider(
        personID: Person.ID,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        usesCoreLocation: Bool = false
    ) -> LocationProviding {
        if usesSimulatedProvider(arguments: arguments) {
            // Timed + wall-clock base so `--live --sim-location` dogfood emits
            // fresh observations that pass age validation and reach presence sync.
            // Unit tests construct providers with `.manual` / frozen baseDate.
            return SimulatedLocationProvider(
                route: SimulatedLocationRouteFixtures.stationary(
                    personID: personID,
                    baseDate: Date()
                ),
                authorizationState: .whenInUse,
                mode: .timed
            )
        }
        if usesCoreLocation {
            return CoreLocationLocationProvider(personID: personID)
        }
        // Mock default: never start production GPS.
        return NullLocationProvider(authorizationState: .notDetermined)
    }

    static func usesSimulatedProvider(arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains(LocationSessionLaunchArgument.simLocation)
        #else
        _ = arguments
        return false
        #endif
    }
}
