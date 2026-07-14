//
//  ProfileScaffolding.swift
//  Push
//
//  Static Day-1 profile UI content (Set Status quick options, privacy/settings
//  toggle copy, Connect card). This is prototype scaffolding, not real social
//  data, so both the mock seed and the live Supabase profile row synthesize
//  it from this single source rather than each hardcoding their own copy.
//

import Foundation

enum ProfileScaffolding {
    static var availabilityOptions: [ProfileAvailabilityOption] { makeAvailabilityOptions() }
    static var activityVisibility: [ProfileToggleItem] { makeActivityVisibility() }
    static var mapPreferences: [ProfileToggleItem] { makeMapPreferences() }
    static var closeFriends: [ProfileToggleItem] { makeCloseFriends() }
    static var connectors: [ProfileConnector] { makeConnectors() }

    private static func makeAvailabilityOptions() -> [ProfileAvailabilityOption] {
        [
            ProfileAvailabilityOption(availability: .freeNow, subtitle: "Open to something nearby"),
            ProfileAvailabilityOption(availability: .maybeDown, subtitle: "Soft signal, no pressure"),
            ProfileAvailabilityOption(availability: .busy, subtitle: "Keep me off the board for now")
        ]
    }

    private static func makeActivityVisibility() -> [ProfileToggleItem] {
        [
            ProfileToggleItem(
                id: "place",
                title: "Place",
                subtitle: "Show a soft nearby place when it helps friends understand the move.",
                symbolName: "mappin.and.ellipse",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "activity",
                title: "Activity",
                subtitle: "Share casual context like coffee, gym, or studying.",
                symbolName: "figure.socialdance",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "with-friends",
                title: "Who you're with",
                subtitle: "Let close friends see when a small group is forming.",
                symbolName: "person.2.fill",
                isEnabled: true
            )
        ]
    }

    private static func makeMapPreferences() -> [ProfileToggleItem] {
        [
            ProfileToggleItem(
                id: "default-close",
                title: "Default to Close Friends",
                subtitle: "Start new sessions with the smallest audience.",
                symbolName: "lock.fill",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "soft-place",
                title: "Use soft places",
                subtitle: "Prefer neighborhoods over exact spots unless you choose otherwise.",
                symbolName: "map",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "show-eta",
                title: "Show ETA while driving",
                subtitle: "Share a loose arrival window when status is Driving / ETA.",
                symbolName: "car.fill",
                isEnabled: false
            )
        ]
    }

    private static func makeCloseFriends() -> [ProfileToggleItem] {
        [
            ProfileToggleItem(
                id: "map",
                title: "Map presence",
                subtitle: "Close friends can see when you're around.",
                symbolName: "location.fill",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "status",
                title: "Status",
                subtitle: "Show availability like Free now or Maybe down.",
                symbolName: "sparkles",
                isEnabled: true
            ),
            ProfileToggleItem(
                id: "pull-up",
                title: "Pull Up signals",
                subtitle: "Allow low-pressure pull-up intent from this audience.",
                symbolName: "hand.wave.fill",
                isEnabled: true
            )
        ]
    }

    private static func makeConnectors() -> [ProfileConnector] {
        [
            ProfileConnector(
                id: "gsuite-calendar",
                title: "GSuite Calendar",
                subtitle: "Use free/busy windows to soften your availability.",
                symbolName: "calendar.badge.clock",
                buttonTitle: "Connect with GSuite",
                permissionCopy: "Push would only read free/busy windows. Event titles, notes, guests, and locations stay private.",
                alertTitle: "GSuite Calendar",
                alertMessage: "This prototype does not start Google sign-in yet. The connector is modeled for availability-only access."
            )
        ]
    }
}
