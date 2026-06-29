//
//  ProfileMockData.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

enum ProfileMockData {
    static let currentUser = ProfileData(
        name: "Manav",
        initials: "MK",
        handle: "@manav",
        imageAssetName: RealWorldMockData.profileImageAssetName,
        availability: .maybeDown,
        activityTitle: "Maybe down",
        placeTitle: "Near Hayes Valley",
        visibilityNote: "Visible to close friends for the next few hours.",
        availabilityOptions: [
            ProfileAvailabilityOption(availability: .freeNow, subtitle: "Open to something nearby"),
            ProfileAvailabilityOption(availability: .maybeDown, subtitle: "Soft signal, no pressure"),
            ProfileAvailabilityOption(availability: .busy, subtitle: "Keep me off the board for now")
        ]
    )

    static let activityVisibility = [
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

    static let mapPreferences = [
        ProfileToggleItem(id: "default-close", title: "Default to Close Friends", subtitle: "Start new sessions with the smallest audience.", symbolName: "lock.fill", isEnabled: true),
        ProfileToggleItem(id: "soft-place", title: "Use soft places", subtitle: "Prefer neighborhoods over exact spots unless you choose otherwise.", symbolName: "map", isEnabled: true),
        ProfileToggleItem(id: "show-eta", title: "Show ETA while driving", subtitle: "Share a loose arrival window when status is Driving / ETA.", symbolName: "car.fill", isEnabled: false)
    ]

    static let closeFriends = [
        ProfileToggleItem(id: "map", title: "Map presence", subtitle: "Close friends can see when you're around.", symbolName: "location.fill", isEnabled: true),
        ProfileToggleItem(id: "status", title: "Status", subtitle: "Show availability like Free now or Maybe down.", symbolName: "sparkles", isEnabled: true),
        ProfileToggleItem(id: "pull-up", title: "Pull Up signals", subtitle: "Allow low-pressure pull-up intent from this audience.", symbolName: "hand.wave.fill", isEnabled: true)
    ]

    static let connectors = [
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
