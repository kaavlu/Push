//
//  LocationSessionFactory.swift
//  Push
//
//  Builds app-lifetime LocationSession instances for mock / DEBUG sim / live.
//  Core Location provider selection is intentionally out of scope (later PR).
//

import Foundation

enum LocationSessionLaunchArgument {
    /// DEBUG dogfood: scripted `SimulatedLocationProvider` instead of null.
    static let simLocation = "--sim-location"
}

enum LocationSessionFactory {
    /// Default session for a container: null provider, or simulated when
    /// `--sim-location` is present (DEBUG process arguments).
    @MainActor
    static func makeDefault(
        personID: Person.ID,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        availabilityProvider: @escaping @MainActor () -> FriendAvailabilityState? = { nil },
        sync: PresenceSyncing = NoOpPresenceSync()
    ) -> LocationSession {
        let provider = makeProvider(personID: personID, arguments: arguments)
        return LocationSession(
            provider: provider,
            validator: LocationObservationValidator(),
            inferrer: PassthroughPresenceInferrer(),
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
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> LocationProviding {
        if usesSimulatedProvider(arguments: arguments) {
            return SimulatedLocationProvider(
                route: SimulatedLocationRouteFixtures.stationary(personID: personID),
                authorizationState: .whenInUse,
                mode: .manual
            )
        }
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
