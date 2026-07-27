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

        let sfStatuses = [
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
        let regionalStatuses = regionalClusterCohorts.flatMap { cohort in
            cohort.personIDs.map { personID in
                status(
                    personID,
                    .busy,
                    PresenceActivity(name: "Around town", symbolName: "building.2.fill"),
                    place: cohort.placeID,
                    note: nil,
                    minutesAgo: 0,
                    now: now
                )
            }
        }
        return sfStatuses + regionalStatuses
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
            availabilityOptions: ProfileScaffolding.availabilityOptions,
            activityVisibility: ProfileScaffolding.activityVisibility,
            mapPreferences: ProfileScaffolding.mapPreferences,
            closeFriends: ProfileScaffolding.closeFriends,
            connectors: ProfileScaffolding.connectors
        )
    }
}
