//
//  ProfileContentBuilder.swift
//  Push
//
//  Builds the profile header presentation model from the canonical user
//  profile, person, and (self-scoped) visible presence.
//

import Foundation

enum ProfileContentBuilder {

    static func profileData(
        profile: UserProfile,
        person: Person,
        presence: VisiblePresence?
    ) -> ProfileData {
        let activity = presence.map { PresenceActivityPresentation.fields(from: $0) }
        return ProfileData(
            name: person.displayName,
            initials: person.initials,
            handle: profile.handle,
            imageAssetName: person.imageAssetPath,
            availability: profile.chosenAvailability,
            // Presence activity stays independent of the availability chip.
            activityTitle: activity?.activityName ?? "",
            placeTitle: placeTitle(from: presence),
            visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions
        )
    }

    /// The profile always shows a soft neighborhood ("soft places" preference),
    /// so it uses the vague label rather than the exact venue name.
    private static func placeTitle(from presence: VisiblePresence?) -> String {
        guard let place = presence?.placeInfo?.place else { return "" }
        return "Near \(place.vagueLabel)"
    }
}
