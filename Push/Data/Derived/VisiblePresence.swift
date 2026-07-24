//
//  VisiblePresence.swift
//  Push
//
//  What a specific viewer is allowed to see of someone's presence, after
//  applying the owner's most specific SharingPolicy. All screen builders
//  consume this — never raw PresenceStatus — so privacy is applied in
//  exactly one place.
//

import Foundation

struct VisiblePresence: Equatable {
    struct VisiblePlaceInfo: Equatable {
        let place: Place
        let isVague: Bool

        var displayName: String { isVague ? place.vagueLabel : place.shortName }
    }

    let person: Person
    let availability: FriendAvailabilityState?
    let activity: PresenceActivity?
    let statusNote: String?
    let placeInfo: VisiblePlaceInfo?
    let updatedAt: Date
    let isCurrentUser: Bool
}

enum VisiblePresenceBuilder {

    /// Most specific active policy wins: friend → group → globalDefault.
    static func resolvedPolicy(
        ownerID: Person.ID,
        viewerID: Person.ID,
        sharedGroupIDs: Set<String>,
        policies: [SharingPolicy],
        now: Date
    ) -> SharingPolicy? {
        let active = policies.filter { policy in
            policy.ownerPersonID == ownerID && (policy.expiresAt.map { $0 > now } ?? true)
        }
        if let friend = active.first(where: { $0.audienceType == .friend && $0.audienceID == viewerID }) {
            return friend
        }
        if let group = active.first(where: { policy in
            policy.audienceType == .group && policy.audienceID.map(sharedGroupIDs.contains) == true
        }) {
            return group
        }
        return active.first { $0.audienceType == .globalDefault }
    }

    /// Returns nil when the viewer isn't allowed to see this person at all.
    static func visiblePresence(
        of status: PresenceStatus,
        owner: Person,
        viewerID: Person.ID,
        sharedGroupIDs: Set<String>,
        policies: [SharingPolicy],
        placesByID: [Place.ID: Place],
        now: Date
    ) -> VisiblePresence? {
        let isSelf = owner.id == viewerID
        var policy: SharingPolicy?
        if !isSelf {
            // Defense in depth: unpublished / legacy Ghost never reach friends
            // even if a status slips past repository filtering.
            guard status.isEffectivelyPublished else { return nil }
            policy = resolvedPolicy(
                ownerID: owner.id,
                viewerID: viewerID,
                sharedGroupIDs: sharedGroupIDs,
                policies: policies,
                now: now
            )
            // No policy means share nothing — hidden is the safe default.
            guard let resolved = policy else { return nil }
            if resolved.availabilityVisibility == .hidden { return nil }
        }

        var activity: PresenceActivity? = status.activity
        var note = status.statusNote
        var placeInfo: VisiblePresence.VisiblePlaceInfo?
        if let placeID = status.placeID, let place = placesByID[placeID] {
            placeInfo = VisiblePresence.VisiblePlaceInfo(place: place, isVague: false)
        }

        if let policy {
            switch policy.activityVisibility {
            case .full:
                break
            case .vague:
                note = nil
            case .hidden:
                activity = nil
                note = nil
            }
            switch policy.locationVisibility {
            case .exact:
                break
            case .vague:
                placeInfo = placeInfo.map { VisiblePresence.VisiblePlaceInfo(place: $0.place, isVague: true) }
            case .hidden:
                placeInfo = nil
            }
        }

        return VisiblePresence(
            person: owner,
            availability: status.availability,
            activity: activity,
            statusNote: note,
            placeInfo: placeInfo,
            updatedAt: status.updatedAt,
            isCurrentUser: isSelf
        )
    }
}
