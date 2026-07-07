//
//  SeedData+Presence.swift
//  Push
//
//  Presence statuses (one per person — "map wins" canonical values) and the
//  current-user profile.
//

import Foundation

extension SeedData {

    // MARK: - Presence

    static func standardStatuses(now: Date) -> [PresenceStatus] {
        let coffee = PresenceActivity(name: "Coffee", symbolName: "cup.and.saucer.fill")
        let park = PresenceActivity(name: "Park", symbolName: "leaf.fill")
        let lunch = PresenceActivity(name: "Lunch", symbolName: "fork.knife")
        let gym = PresenceActivity(name: "Gym", symbolName: "dumbbell.fill")
        let off = PresenceActivity(name: "Off", symbolName: "moon.zzz.fill")

        return [
            status("chitty", .freeNow, coffee, place: "blue-bottle", note: nil, minutesAgo: 3, now: now),
            status("nitin", .maybeDown, park, place: "dolores-park", note: "Near Dolores", minutesAgo: 8, now: now),
            status("ishan", .freeNow, lunch, place: "souvla", note: nil, minutesAgo: 0, now: now),
            status("viplove", .joinable, lunch, place: "souvla", note: "With Ishan", minutesAgo: 0, now: now),
            status("rohan", .joinable, park, place: "dolores-lawn", note: "Walking over", minutesAgo: 5, now: now),
            status("ryan", .maybeDown, park, place: "dolores-lawn", note: "Free in 20", minutesAgo: 5, now: now),
            status("pranay", .freeSoon, park, place: "dolores-lawn", note: "Maybe pulling up", minutesAgo: 5, now: now),
            status("ram", .maybeDown, gym, place: "crunch", note: "Wrapping up", minutesAgo: 12, now: now),
            status("ohm", .busy, gym, place: "crunch", note: "With Ram", minutesAgo: 12, now: now),
            status(SeedIDs.currentUser, .maybeDown, park, place: "north-park", note: "Near North Park", minutesAgo: 0, now: now),
            status("roh", .unavailable, off, place: nil, note: nil, minutesAgo: 60, now: now)
        ]
    }

    private static func status(
        _ personID: String,
        _ availability: FriendAvailabilityState,
        _ activity: PresenceActivity,
        place placeID: String?,
        note: String?,
        minutesAgo: Double,
        now: Date
    ) -> PresenceStatus {
        let updatedAt = now.addingTimeInterval(-minutesAgo * SeedTime.minute)
        return PresenceStatus(
            id: "status-\(personID)",
            personID: personID,
            availability: availability,
            activity: activity,
            placeID: placeID,
            statusNote: note,
            confidence: .high,
            observedAt: updatedAt,
            updatedAt: updatedAt,
            expiresAt: nil,
            source: .seed
        )
    }

    // MARK: - Profile

    static func standardProfile() -> UserProfile {
        UserProfile(
            personID: SeedIDs.currentUser,
            handle: "@manav",
            chosenAvailability: .maybeDown,
            visibilityNote: "Visible to close friends for the next few hours.",
            availabilityOptions: [
                ProfileAvailabilityOption(availability: .freeNow, subtitle: "Open to something nearby"),
                ProfileAvailabilityOption(availability: .maybeDown, subtitle: "Soft signal, no pressure"),
                ProfileAvailabilityOption(availability: .busy, subtitle: "Keep me off the board for now")
            ],
            activityVisibility: [
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
            ],
            mapPreferences: [
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
            ],
            closeFriends: [
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
            ],
            connectors: [
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
        )
    }
}
